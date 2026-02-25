"""
Integration tests for COBOL programs via Python bridge.

These tests exercise the full COBOLBridge workflow -- from seeding accounts
to processing transactions to verifying integrity chains. They run in Mode B
(Python-only validation), which is sufficient for CI testing because Mode B
implements the same business rules as the COBOL programs.

Why Mode B is sufficient for CI:
    The COBOL programs and Mode B share the same business rules (status codes,
    balance math, daily limits, account freezing). Mode B is a faithful Python
    implementation of COBOL's VALIDATE.cob and TRANSACT.cob logic. The only
    thing Mode B doesn't test is the COBOL stdout parsing -- that's covered
    by manual testing with actual COBOL binaries.

What integration tests prove vs unit tests:
    Unit tests (test_bridge.py) test individual methods in isolation.
    Integration tests verify multi-step workflows:
    - Deposit then withdraw: balance math chains correctly
    - Transfer is zero-sum: source + dest = original total
    - Multiple transactions grow the chain, all entries remain valid
    - Frozen accounts block ALL operations (not just one type)
    - Two nodes operate independently without interference
    - 50+ transactions in batch don't break anything
    - Simulation engine produces valid chains

Test naming convention:
    CI01 through CI15 -- sequential IDs for traceability.
"""

import pytest
import tempfile
import shutil
from pathlib import Path
from ..bridge import COBOLBridge


@pytest.fixture
def temp_data_dir():
    """Create a temporary data directory for testing."""
    temp_dir = Path(tempfile.mkdtemp())
    yield temp_dir
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def bridge(temp_data_dir):
    """Create a COBOLBridge instance with seeded demo data.

    Uses a nonexistent bin_dir to force Mode B (Python-only validation).
    The seed_demo_data() call populates BANK_A's 8 demo accounts so
    tests can transact against realistic data.
    """
    b = COBOLBridge(node="BANK_A", data_dir=str(temp_data_dir), bin_dir="nonexistent/bin")
    b.seed_demo_data()
    return b


@pytest.fixture
def bridge_b(temp_data_dir):
    """Create a second COBOLBridge instance for isolation tests.

    BANK_B is a separate node with its own database, chain, and accounts.
    Used by CI11 to prove that nodes don't interfere with each other.
    """
    b = COBOLBridge(node="BANK_B", data_dir=str(temp_data_dir), bin_dir="nonexistent/bin")
    b.seed_demo_data()
    return b


# ── CI01: Deposit then withdraw ──────────────────────────────────
# Proves: balance math is correct through sequential operations.

def test_deposit_then_withdraw(bridge):
    """Deposit then withdraw: balance math correct through bridge."""
    # Get initial balance
    acct = bridge.get_account("ACT-A-001")
    initial = acct["balance"]

    # Deposit $500
    r1 = bridge.process_transaction("ACT-A-001", "D", 500.00, "Test deposit")
    assert r1["status"] == "00"
    assert r1["new_balance"] == pytest.approx(initial + 500.00, abs=0.01)

    # Withdraw $200
    r2 = bridge.process_transaction("ACT-A-001", "W", 200.00, "Test withdrawal")
    assert r2["status"] == "00"
    assert r2["new_balance"] == pytest.approx(initial + 300.00, abs=0.01)


# ── CI02: Transfer is zero-sum ────────────────────────────────────
# Proves: intra-bank transfers move money, never create or destroy it.

def test_transfer_zero_sum(bridge):
    """Transfer: source + target = original total (zero-sum)."""
    src = bridge.get_account("ACT-A-001")
    dst = bridge.get_account("ACT-A-005")
    original_total = src["balance"] + dst["balance"]

    result = bridge.process_transaction(
        "ACT-A-001", "T", 1000.00, "Transfer test", target_id="ACT-A-005"
    )
    assert result["status"] == "00"

    src_after = bridge.get_account("ACT-A-001")
    dst_after = bridge.get_account("ACT-A-005")
    assert src_after["balance"] + dst_after["balance"] == pytest.approx(
        original_total, abs=0.01
    )


# ── CI03: Multiple TX chain ──────────────────────────────────────
# Proves: the integrity chain grows with each transaction and all
# entries remain valid (hash linkage + HMAC signatures).

def test_multiple_tx_chain(bridge):
    """Multiple transactions grow the hash chain, all entries valid."""
    for i in range(5):
        result = bridge.process_transaction(
            "ACT-A-001", "D", 100.00, f"Chain test {i}"
        )
        assert result["status"] == "00"

    chain_result = bridge.chain.verify_chain()
    assert chain_result["valid"] is True
    assert chain_result["entries_checked"] == 5


# ── CI04: Frozen blocks all ops ──────────────────────────────────
# Proves: a frozen account (status=F) rejects ALL transaction types,
# not just withdrawals. This is a security control.

def test_frozen_blocks_all_ops(bridge):
    """Frozen account (status=F) rejects deposit, withdrawal, transfer."""
    # Freeze the account in DB
    bridge.db.execute(
        "UPDATE accounts SET status = 'F' WHERE id = 'ACT-A-001'"
    )
    bridge.db.commit()

    r_deposit = bridge.process_transaction("ACT-A-001", "D", 100.00, "Deposit frozen")
    assert r_deposit["status"] == "04"

    r_withdraw = bridge.process_transaction("ACT-A-001", "W", 100.00, "Withdraw frozen")
    assert r_withdraw["status"] == "04"

    r_transfer = bridge.process_transaction(
        "ACT-A-001", "T", 100.00, "Transfer frozen", target_id="ACT-A-005"
    )
    assert r_transfer["status"] == "04"


# ── CI05: Daily limit enforced ────────────────────────────────────
# Proves: the $50,000 daily limit from TRANSACT.cob is enforced in Mode B.

def test_daily_limit_enforced(bridge):
    """$50,000 daily limit blocks oversized transactions."""
    # Need high balance to avoid NSF before limit check
    bridge.db.execute(
        "UPDATE accounts SET balance = 100000.00 WHERE id = 'ACT-A-001'"
    )
    bridge.db.commit()

    # Bridge Mode B limit: amount > 50000.00
    result = bridge.process_transaction(
        "ACT-A-001", "W", 50001.00, "Over limit"
    )
    assert result["status"] == "02"


# ── CI06: Penny precision ────────────────────────────────────────
# Proves: $0.01 transactions round-trip correctly without floating-point drift.
# This is critical for COBOL's PIC S9(10)V99 implied-decimal format.

def test_penny_precision(bridge):
    """$0.01 deposit and withdrawal round-trip correctly."""
    initial = bridge.get_account("ACT-A-001")["balance"]

    r1 = bridge.process_transaction("ACT-A-001", "D", 0.01, "Penny in")
    assert r1["status"] == "00"
    assert r1["new_balance"] == pytest.approx(initial + 0.01, abs=0.005)

    r2 = bridge.process_transaction("ACT-A-001", "W", 0.01, "Penny out")
    assert r2["status"] == "00"
    assert r2["new_balance"] == pytest.approx(initial, abs=0.005)


# ── CI07: Max balance ────────────────────────────────────────────
# Proves: PIC S9(10)V99 max value ($9,999,999,999.99) is handled correctly.

def test_max_balance(bridge):
    """PIC S9(10)V99 max = $9,999,999,999.99 round-trips."""
    bridge.db.execute(
        "UPDATE accounts SET balance = 9999999999.99 WHERE id = 'ACT-A-001'"
    )
    bridge.db.commit()
    acct = bridge.get_account("ACT-A-001")
    assert acct["balance"] == pytest.approx(9999999999.99, abs=0.01)


# ── CI08: TX ID monotonic ────────────────────────────────────────
# Proves: transaction IDs are unique and monotonically increasing.
# This prevents duplicate transaction references.

def test_tx_id_monotonic(bridge):
    """Transaction IDs are monotonically increasing, never repeat."""
    tx_ids = []
    for i in range(5):
        result = bridge.process_transaction("ACT-A-001", "D", 10.00, f"TX {i}")
        assert result["status"] == "00"
        tx_ids.append(result["tx_id"])

    # All unique
    assert len(set(tx_ids)) == 5

    # Sequence numbers are increasing
    seqs = [int(tid.split("-")[-1]) for tid in tx_ids]
    assert seqs == sorted(seqs)
    assert seqs[-1] > seqs[0]


# ── CI09: ACCOUNTS.DAT round-trip ─────────────────────────────────
# Proves: seed_demo_data() writes valid DAT files that can be parsed
# back with correct field values. Tests the full write -> read cycle.

def test_accounts_dat_roundtrip(bridge):
    """Write accounts to DAT, reload, fields match."""
    original = bridge.load_accounts_from_dat()
    assert len(original) == 8  # BANK_A has 8 accounts

    # Check first account fields
    acct = original[0]
    assert acct["id"] == "ACT-A-001"
    assert acct["name"] == "Maria Santos"
    assert acct["type"] == "C"
    assert acct["balance"] == pytest.approx(5000.00, abs=0.01)
    assert acct["status"] == "A"


# ── CI10: TRANSACT.DAT format ─────────────────────────────────────
# Proves: in Mode B, transactions go to SQLite (not TRANSACT.DAT).
# Verifies the SQLite record has correct fields.

def test_transact_dat_format(bridge):
    """After a transaction, TRANSACT.DAT is not created in Mode B
    (transactions go to SQLite). Verify SQLite record format."""
    result = bridge.process_transaction("ACT-A-001", "D", 500.00, "Format test")
    assert result["status"] == "00"

    # Verify transaction in SQLite
    cursor = bridge.db.execute(
        "SELECT tx_id, account_id, type, amount, status FROM transactions WHERE tx_id = ?",
        (result["tx_id"],),
    )
    row = cursor.fetchone()
    assert row is not None
    assert row["account_id"] == "ACT-A-001"
    assert row["type"] == "D"
    assert row["amount"] == pytest.approx(500.00, abs=0.01)
    assert row["status"] == "00"


# ── CI11: Two nodes isolated ─────────────────────────────────────
# Proves: separate bridge instances for different nodes have completely
# independent databases and chains. BANK_A transactions don't appear in
# BANK_B's data.

def test_two_nodes_isolated(bridge, bridge_b):
    """Separate bridge instances don't interfere with each other."""
    # Deposit into BANK_A
    r_a = bridge.process_transaction("ACT-A-001", "D", 1000.00, "BANK_A deposit")
    assert r_a["status"] == "00"

    # BANK_B should not see BANK_A's transaction
    b_accounts = bridge_b.list_accounts()
    b_ids = [a["id"] for a in b_accounts]
    assert "ACT-A-001" not in b_ids

    # BANK_B chain is independent
    chain_b = bridge_b.chain.verify_chain()
    assert chain_b["entries_checked"] == 0  # No transactions in BANK_B


# ── CI12: Batch 50+ transactions ─────────────────────────────────
# Proves: the system handles bulk operations without errors, and the
# integrity chain remains valid after many sequential writes.

def test_batch_stress(bridge):
    """50 deposits processed without error."""
    for i in range(50):
        result = bridge.process_transaction(
            "ACT-A-001", "D", 1.00, f"Stress test {i}"
        )
        assert result["status"] == "00", f"Failed at iteration {i}"

    # Verify chain integrity after bulk operations
    chain_result = bridge.chain.verify_chain()
    assert chain_result["valid"] is True
    assert chain_result["entries_checked"] == 50

    # Verify balance increased by $50
    acct = bridge.get_account("ACT-A-001")
    assert acct["balance"] == pytest.approx(5050.00, abs=0.01)


# ── CI13: First TX creates entries ────────────────────────────────
# Proves: the system works correctly on a brand-new node with no
# prior transactions (genesis chain state).

def test_first_tx_works(temp_data_dir):
    """Transaction works on a freshly initialized bridge with no prior TXs."""
    b = COBOLBridge(node="BANK_TEST", data_dir=str(temp_data_dir), bin_dir="nonexistent/bin")
    b.seed_demo_data()

    # Insert a single test account
    b.db.execute(
        "INSERT OR REPLACE INTO accounts (id, name, type, balance, status) VALUES (?, ?, ?, ?, ?)",
        ("ACT-X-001", "First TX Test", "C", 1000.00, "A"),
    )
    b.db.commit()

    result = b.process_transaction("ACT-X-001", "D", 100.00, "First ever TX")
    assert result["status"] == "00"
    assert result["tx_id"].startswith("TRX-")

    chain_result = b.chain.verify_chain()
    assert chain_result["valid"] is True
    assert chain_result["entries_checked"] == 1


# ── CI14: Cross-verify post-settlement (multi-node integrity) ────
# Proves: two nodes can process independent transactions and both
# chains remain valid. This is a prerequisite for cross-node verification.

def test_cross_verify_multi_node(temp_data_dir):
    """Two nodes process independent transactions, both chains remain valid."""
    b_a = COBOLBridge(
        node="BANK_A", data_dir=str(temp_data_dir), bin_dir="nonexistent/bin"
    )
    b_c = COBOLBridge(
        node="BANK_C", data_dir=str(temp_data_dir), bin_dir="nonexistent/bin"
    )
    b_a.seed_demo_data()
    b_c.seed_demo_data()

    # Process transactions on both nodes
    r1 = b_a.process_transaction("ACT-A-001", "D", 500.00, "Node A tx")
    assert r1["status"] == "00"

    r2 = b_c.process_transaction("ACT-C-001", "D", 750.00, "Node C tx")
    assert r2["status"] == "00"

    # Both chains valid independently
    assert b_a.chain.verify_chain()["valid"] is True
    assert b_c.chain.verify_chain()["valid"] is True

    # Chains are separate (different secret keys, different entries)
    a_entries = b_a.chain.verify_chain()["entries_checked"]
    c_entries = b_c.chain.verify_chain()["entries_checked"]
    assert a_entries == 1
    assert c_entries == 1


# ── CI15: 2-day simulation smoke test ─────────────────────────────
# Proves: the simulation engine can run a short deterministic simulation
# and all chains remain valid afterward. This is an end-to-end smoke test
# covering seeding -> simulation -> chain verification.

def test_simulation_smoke(temp_data_dir):
    """Short deterministic simulation completes with valid chains."""
    from ..simulator import SimulationEngine, BANKS

    # Seed all nodes first -- SimulationEngine expects pre-populated account data
    for node in ['BANK_A', 'BANK_B', 'BANK_C', 'BANK_D', 'BANK_E', 'CLEARING']:
        b = COBOLBridge(node=node, data_dir=str(temp_data_dir), bin_dir="nonexistent/bin")
        b.seed_demo_data()
        b.close()

    engine = SimulationEngine(
        data_dir=str(temp_data_dir),
        seed=42,
        time_scale=0,         # No sleep between events
        tx_range=(5, 10),     # Few TXs per day for speed
        verify_every=2,       # Verify at end
        monthly_events=False, # Skip interest/fees for speed
    )
    engine.run(days=2)

    assert engine.total_completed > 0, "No transactions completed"
    assert engine.days_run == 2, f"Expected 2 days, got {engine.days_run}"

    # All chains valid
    for bank in BANKS:
        chain_result = engine.coordinator.nodes[bank].chain.verify_chain()
        assert chain_result["valid"] is True, f"{bank} chain invalid"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
