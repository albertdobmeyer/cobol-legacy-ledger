"""
cross_verify.py -- Cross-node integrity verification for multi-bank settlement.

This module answers the question: "Do all 6 nodes agree on what happened?"

Each banking node maintains its own independent integrity chain (hash chain +
HMAC signatures in SQLite). The settlement coordinator creates matching entries
across 3 nodes for every inter-bank transfer. This module walks all 6 chains
and cross-references settlement entries to detect discrepancies.

Three layers of verification:
    1. Per-chain hash integrity -- Does each node's chain link correctly?
       (Catches: modified entries, deleted entries, broken hashes)

    2. Balance reconciliation -- Does the ACCOUNTS.DAT file match the SQLite
       database? (Catches: direct file tampering that bypasses COBOL)

    3. Settlement cross-referencing -- For each settlement reference
       (STL-YYYYMMDD-NNNNNN), do all 3 expected entries (source bank,
       clearing house x2, destination bank) exist with matching amounts?
       (Catches: missing legs, amount mismatches, fabricated entries)

What this CAN detect:
    - Someone editing ACCOUNTS.DAT directly (balance drift)
    - A modified or deleted chain entry (hash linkage break)
    - A missing settlement leg (e.g., money debited but never credited)
    - Amount discrepancies across nodes (source says $500, dest says $600)

What this CANNOT detect:
    - Collusion between all 6 nodes (if everyone agrees on the lie)
    - Tampering that also recomputes hashes AND possesses the HMAC key
    - Transactions that never entered any chain (pre-chain fraud)

The clearing house chain is the authoritative record. When bank chains
disagree with clearing, the clearing chain is treated as ground truth.

Dependencies: integrity.py (for per-chain verification), bridge.py (for node access)
"""

import re
import sqlite3
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any
from datetime import datetime
from pathlib import Path
from .bridge import COBOLBridge


@dataclass
class SettlementMatch:
    """Result of cross-referencing one settlement across nodes.

    For a MATCHED settlement, all 4 entries exist (source, 2x clearing, dest)
    and all amounts agree. PARTIAL means some entries are missing (e.g., the
    destination credit failed due to NSF). MISMATCH means entries exist but
    amounts disagree. ORPHAN means a settlement ref was found but no entries
    could be located (shouldn't happen in normal operation).
    """
    settlement_ref: str
    status: str            # "MATCHED" | "PARTIAL" | "MISMATCH" | "ORPHAN"
    amount: float
    source_bank: str
    dest_bank: str
    source_entry_found: bool
    clearing_entries_found: int  # 0, 1, or 2
    dest_entry_found: bool
    discrepancies: List[str] = field(default_factory=list)


@dataclass
class VerificationReport:
    """Complete cross-node verification results.

    This is the final output of verify_all() -- a comprehensive report
    covering all three verification layers. The all_chains_intact and
    all_settlements_matched booleans provide quick pass/fail, while
    the anomalies list gives human-readable details on failures.
    """
    timestamp: str

    # Per-chain hash integrity (cryptographic linkage only)
    chain_integrity: Dict[str, bool]
    chain_lengths: Dict[str, int]

    # Balance reconciliation (DAT vs DB -- separate from chain integrity)
    balance_drift: Dict[str, List[str]]

    # Cross-node settlement matching
    settlements_checked: int
    settlements_matched: int
    settlements_partial: int
    settlements_mismatched: int
    settlements_orphaned: int
    settlement_details: List[SettlementMatch]

    # Summary
    all_chains_intact: bool
    all_settlements_matched: bool
    anomalies: List[str]

    # Performance
    verification_time_ms: float


class CrossNodeVerifier:
    """Cross-node integrity verification engine.

    Creates a COBOLBridge for each of the 6 nodes and performs all three
    layers of verification. Designed to run periodically (e.g., every 5
    simulation days) or on-demand via the CLI 'verify --cross-node' command.
    """

    NODES = ['BANK_A', 'BANK_B', 'BANK_C', 'BANK_D', 'BANK_E', 'CLEARING']

    def __init__(self, data_dir: str = "COBOL-BANKING/data", bridges: dict = None):
        """Load all 6 node bridges, or reuse existing ones.

        :param bridges: Optional dict of node_name -> COBOLBridge to reuse.
            When provided, the verifier borrows these bridges instead of creating
            new ones. This avoids SQLite lock contention when the simulator calls
            verification mid-run (both would otherwise open competing connections).
        """
        self.data_dir = data_dir
        self._owns_bridges = bridges is None
        if bridges is not None:
            self.bridges = dict(bridges)
        else:
            self.bridges = {}
            for node in self.NODES:
                self.bridges[node] = COBOLBridge(node=node, data_dir=data_dir)

    def verify_all(self) -> VerificationReport:
        """
        Full cross-node verification:
        1. Verify each chain's hash integrity independently
        2. Check DAT vs SQLite balance reconciliation
        3. Extract all settlement references from all chains
        4. Cross-reference entries across chains
        5. Report anomalies
        """
        start_time = datetime.now()

        # ── Layer 1: Per-Chain Hash Integrity ─────────────────────────
        # Each node's chain is verified independently using IntegrityChain.
        # A broken chain means someone tampered with the SQLite database
        # (modified a hash, deleted an entry, etc.)
        chain_integrity = {}
        chain_lengths = {}
        anomalies = []

        for node in self.NODES:
            result = self.bridges[node].chain.verify_chain()
            chain_integrity[node] = result['valid']
            chain_lengths[node] = result['entries_checked']
            if not result['valid']:
                anomalies.append(
                    f"{node} chain hash mismatch at entry #{result['first_break']} "
                    f"({result['break_type']})"
                )

        # Load all chain entries (needed for balance check and cross-ref)
        all_entries = {}
        for node in self.NODES:
            entries = self._get_chain_entries_with_details(node)
            all_entries[node] = entries

        # ── Layer 2: Balance Reconciliation ───────────────────────────
        # Compare ACCOUNTS.DAT (what COBOL sees) against SQLite (what the
        # bridge recorded). Balance drift is expected during simulation
        # (internal activity changes DAT balances without updating stale
        # DB snapshots). This is informational, NOT a chain integrity failure.
        # However, UNEXPECTED drift (e.g., direct DAT file editing) is a
        # tamper indicator.
        balance_drift = {}
        for node in self.NODES:
            balance_issues = self._check_balance_reconciliation(node, all_entries.get(node, []))
            if balance_issues:
                balance_drift[node] = balance_issues

        # ── Layer 3: Settlement Cross-Referencing ─────────────────────
        # Collect all settlement references (STL-YYYYMMDD-NNNNNN) from
        # every chain entry's description, then verify each one has
        # matching entries across all expected nodes.
        #
        # Performance: Pre-index entries by settlement ref so each
        # cross-reference is O(1) lookup instead of O(total_entries) scan.
        # Without this, O(refs × entries × nodes) becomes minutes after
        # a few simulation days with hundreds of external transfers.
        entries_by_ref = {}   # ref -> list of (node, entry)
        settlement_refs = set()
        for node, entries in all_entries.items():
            for entry in entries:
                ref = self._extract_settlement_ref(entry.get('description', ''))
                if ref:
                    settlement_refs.add(ref)
                    entries_by_ref.setdefault(ref, []).append(entry)

        settlement_details = []
        matched = 0
        partial = 0
        mismatched = 0
        orphaned = 0

        for ref in sorted(settlement_refs):
            match = self._cross_reference_settlement_indexed(ref, entries_by_ref.get(ref, []))
            settlement_details.append(match)
            if match.status == "MATCHED":
                matched += 1
            elif match.status == "PARTIAL":
                partial += 1
                anomalies.extend(match.discrepancies)
            elif match.status == "MISMATCH":
                mismatched += 1
                anomalies.extend(match.discrepancies)
            elif match.status == "ORPHAN":
                orphaned += 1
                anomalies.extend(match.discrepancies)

        elapsed_ms = (datetime.now() - start_time).total_seconds() * 1000

        return VerificationReport(
            timestamp=datetime.now().isoformat(),
            chain_integrity=chain_integrity,
            chain_lengths=chain_lengths,
            balance_drift=balance_drift,
            settlements_checked=len(settlement_refs),
            settlements_matched=matched,
            settlements_partial=partial,
            settlements_mismatched=mismatched,
            settlements_orphaned=orphaned,
            settlement_details=settlement_details,
            all_chains_intact=all(chain_integrity.values()),
            all_settlements_matched=(matched == len(settlement_refs)),
            anomalies=anomalies,
            verification_time_ms=elapsed_ms,
        )

    def _get_chain_entries_with_details(self, node: str) -> List[Dict[str, Any]]:
        """Get all chain entries with full details for a node.

        Returns raw chain data including the description field, which
        contains the settlement reference needed for cross-referencing.
        """
        db = self.bridges[node].db
        cursor = db.execute("""
            SELECT chain_index, tx_id, account_id, tx_type, amount,
                   timestamp, description, status, tx_hash, prev_hash
            FROM chain_entries
            ORDER BY chain_index
        """)
        return [
            {
                'chain_index': row[0],
                'tx_id': row[1],
                'account_id': row[2],
                'tx_type': row[3],
                'amount': row[4],
                'timestamp': row[5],
                'description': row[6],
                'status': row[7],
                'tx_hash': row[8],
                'prev_hash': row[9],
                'node': node,
            }
            for row in cursor.fetchall()
        ]

    def _extract_settlement_ref(self, description: str) -> Optional[str]:
        """Extract STL-YYYYMMDD-NNNNNN from a description string.

        Settlement references are embedded in transaction descriptions by
        the SettlementCoordinator. This regex extracts them for cross-referencing.
        """
        match = re.search(r'(STL-\d{8}-\d{6})', description)
        return match.group(1) if match else None

    def _cross_reference_settlement_indexed(self, ref: str, ref_entries: List[Dict]) -> SettlementMatch:
        """Cross-reference a settlement using pre-indexed entries (O(k) per ref).

        Unlike _cross_reference_settlement which scans ALL entries from ALL nodes,
        this receives only the entries already known to contain this ref.
        """
        source_entry = None
        dest_entry = None
        clearing_entries = []

        for entry in ref_entries:
            desc = entry.get('description', '')
            if 'XFER-TO-' in desc:
                source_entry = entry
            elif 'XFER-FROM-' in desc:
                dest_entry = entry
            elif 'SETTLE-' in desc:
                clearing_entries.append(entry)

        return self._classify_settlement(ref, source_entry, dest_entry, clearing_entries)

    def _cross_reference_settlement(self, ref: str, all_entries: Dict) -> SettlementMatch:
        """Cross-reference a single settlement across all nodes (full scan).

        Used by find_settlement_entries() for on-demand lookups. For bulk
        verification, use _cross_reference_settlement_indexed() instead.
        """
        source_entry = None
        dest_entry = None
        clearing_entries = []

        for node, entries in all_entries.items():
            for entry in entries:
                desc = entry.get('description', '')
                if ref not in desc:
                    continue
                if 'XFER-TO-' in desc:
                    source_entry = entry
                elif 'XFER-FROM-' in desc:
                    dest_entry = entry
                elif 'SETTLE-' in desc:
                    clearing_entries.append(entry)

        return self._classify_settlement(ref, source_entry, dest_entry, clearing_entries)

    def _classify_settlement(self, ref: str, source_entry, dest_entry, clearing_entries) -> SettlementMatch:
        """Classify a settlement as MATCHED/PARTIAL/MISMATCH/ORPHAN.

        Shared logic for both indexed and full-scan cross-referencing.
        A complete settlement has 1 source + 2 clearing + 1 destination = 4 entries.
        """
        source_bank = source_entry['node'] if source_entry else ''
        dest_bank = dest_entry['node'] if dest_entry else ''
        amount = source_entry['amount'] if source_entry else (
            dest_entry['amount'] if dest_entry else (
                clearing_entries[0]['amount'] if clearing_entries else 0.0
            )
        )

        discrepancies = []
        has_source = source_entry is not None
        has_dest = dest_entry is not None
        num_clearing = len(clearing_entries)

        if has_source and has_dest and num_clearing == 2:
            amounts = {source_entry['amount'], dest_entry['amount']}
            amounts.update(e['amount'] for e in clearing_entries)
            if len(amounts) == 1:
                status = "MATCHED"
            else:
                status = "MISMATCH"
                discrepancies.append(
                    f"Amount mismatch for {ref}: source={source_entry['amount']}, "
                    f"dest={dest_entry['amount']}, clearing={[e['amount'] for e in clearing_entries]}"
                )
        elif has_source or has_dest or num_clearing > 0:
            missing = []
            if not has_source:
                missing.append("source bank entry")
            if not has_dest:
                missing.append("dest bank entry")
            if num_clearing < 2:
                missing.append(f"clearing entries ({num_clearing}/2)")
            status = "PARTIAL"
            discrepancies.append(f"Incomplete settlement {ref}: missing {', '.join(missing)}")
        else:
            status = "ORPHAN"
            discrepancies.append(f"Orphan settlement reference {ref}: no entries found")

        return SettlementMatch(
            settlement_ref=ref,
            status=status,
            amount=amount,
            source_bank=source_bank,
            dest_bank=dest_bank,
            source_entry_found=has_source,
            clearing_entries_found=num_clearing,
            dest_entry_found=has_dest,
            discrepancies=discrepancies,
        )

    def _check_balance_reconciliation(self, node: str, chain_entries: List[Dict]) -> List[str]:
        """
        Compare current ACCOUNTS.DAT balances against the SQLite accounts table.

        This is the tamper detection layer for direct file edits. The accounts
        table was populated by _sync_accounts_to_db() which reads COBOL's
        ACCOUNTS LIST output (or the DAT file directly). After each transaction,
        the bridge updates the DB balance to match what COBOL reported.

        If someone tampers the DAT file directly (bypassing COBOL and the chain),
        the DAT balance will diverge from the DB balance. This check catches that.

        The chain entry count per account is included for context -- it helps
        distinguish "balance changed because of legitimate transactions" from
        "balance changed because someone edited the file."
        """
        issues = []
        bridge = self.bridges[node]

        # Get current balances from ACCOUNTS.DAT (raw file read)
        current_accounts = bridge.load_accounts_from_dat()
        if not current_accounts:
            return issues

        # Get last-known balances from SQLite (synced after each COBOL operation)
        db_accounts = {}
        try:
            cursor = bridge.db.execute("SELECT id, balance FROM accounts")
            for row in cursor.fetchall():
                db_accounts[row[0].strip()] = row[1]
        except Exception:
            return issues

        # Compare DAT file balance vs DB balance for each account
        for acct in current_accounts:
            acct_id = acct['id']
            dat_balance = acct['balance']
            db_balance = db_accounts.get(acct_id)

            if db_balance is None:
                continue  # Account not tracked in DB

            if abs(dat_balance - db_balance) > 0.01:
                # Count chain entries for context
                tx_count = sum(
                    1 for entry in chain_entries
                    if entry['account_id'].strip() == acct_id
                )
                issues.append(
                    f"{node} balance tamper detected: {acct_id} "
                    f"DAT=${dat_balance:.2f} expected=${db_balance:.2f} "
                    f"(chain records {tx_count} transactions)"
                )

        return issues

    def find_settlement_entries(self, settlement_ref: str) -> Dict:
        """Find all entries related to a settlement reference across all chains.

        Useful for debugging a specific settlement -- returns the full
        SettlementMatch with all entries and discrepancies.
        """
        all_entries = {}
        for node in self.NODES:
            all_entries[node] = self._get_chain_entries_with_details(node)
        return self._cross_reference_settlement(settlement_ref, all_entries)

    def close(self):
        """Close all bridge connections (only if we own them)."""
        if self._owns_bridges:
            for bridge in self.bridges.values():
                bridge.close()


# ── Demo Tamper Function ──────────────────────────────────────
# This function exists ONLY for demonstration purposes. It directly modifies
# a balance in the ACCOUNTS.DAT file, bypassing both COBOL and the integrity
# chain. After calling this, cross_verify will detect the discrepancy between
# the DAT file and the SQLite database.
#
# In a real attack scenario, this is exactly what a malicious insider or
# compromised system would do -- edit the flat file that COBOL reads,
# hoping nobody notices. The integrity layer catches it.

def tamper_balance(data_dir: str, node: str, account_id: str, new_amount: float):
    """
    DEMO ONLY: Directly modify an account balance in the .DAT file.
    Bypasses COBOL and the integrity chain, creating a detectable discrepancy.
    """
    dat_file = Path(data_dir) / node / "ACCOUNTS.DAT"
    if not dat_file.exists():
        raise FileNotFoundError(f"{dat_file} not found")

    # Read all records
    with open(dat_file, 'rb') as f:
        lines = f.readlines()

    # Find and modify the target account
    modified = False
    for i, line in enumerate(lines):
        line = line.rstrip(b'\n\r')
        if len(line) < 70:
            line = line.ljust(70)
        acct_id = line[0:10].decode('ascii').strip()
        if acct_id == account_id:
            # Build new balance bytes
            balance_int = int(abs(new_amount) * 100)
            balance_str = f"{balance_int:012d}"
            if new_amount < 0:
                balance_str = "-" + balance_str[1:]
            # Replace balance bytes (positions 41-53) in the 70-byte record
            new_line = line[:41] + balance_str.encode('ascii') + line[53:]
            lines[i] = new_line + b'\n'
            modified = True
            break

    if not modified:
        raise ValueError(f"Account {account_id} not found in {dat_file}")

    # Write back
    with open(dat_file, 'wb') as f:
        f.writelines(lines)

    return {
        'node': node,
        'account_id': account_id,
        'new_amount': new_amount,
        'file': str(dat_file),
    }
