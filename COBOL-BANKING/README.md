# COBOL-BANKING

Pure GnuCOBOL hub-and-spoke banking simulation. 5 banks + 1 clearing house, 42 accounts, deterministic daily transactions with inter-bank settlement.

No Python. No frameworks. Just COBOL.

## Quick Start

```bash
# 1. Compile (requires GnuCOBOL)
./scripts/build.sh

# 2. Seed 42 demo accounts across 6 nodes
./scripts/seed.sh

# 3. Run 25-day simulation
./scripts/run-simulation.sh 25
```

## Architecture

```
BANK_A ─┐                    ┌─ BANK_A
BANK_B ─┤   OUTBOUND.DAT     │  BANK_B
BANK_C ─┼──────────────────>──┼─ BANK_C    (SETTLE)
BANK_D ─┤   (SIMULATE)       │  BANK_D
BANK_E ─┘                    └─ BANK_E

         5 banks generate        Clearing house settles
         daily transactions      via nostro accounts
```

Each day:
1. **SIMULATE** runs per-bank: deposits, withdrawals, internal transfers, outbound transfers
2. **SETTLE** runs at clearing: reads all OUTBOUND.DAT files, debits/credits nostro accounts

Nostro balances always sum to $50,000,000 (conservation invariant).

## Programs (10)

| Program | Purpose |
|---------|---------|
| ACCOUNTS | Account lifecycle (CREATE, READ, UPDATE, CLOSE, LIST) |
| TRANSACT | Transaction engine (DEPOSIT, WITHDRAW, TRANSFER, BATCH) |
| VALIDATE | Business rule validation (NSF, limits, frozen accounts) |
| REPORTS | Reporting (STATEMENT, LEDGER, EOD, AUDIT) |
| FEES | Monthly fee processing with balance floor protection |
| INTEREST | Interest calculation on savings accounts |
| RECONCILE | Balance reconciliation with implied opening balance |
| SIMULATE | Deterministic daily transaction generator |
| SETTLE | 3-leg inter-bank settlement through clearing house |
| SMOKETEST | Compilation and runtime smoke test |

## Record Formats

**ACCTREC** (70 bytes): `ACCT-ID(10) | NAME(30) | TYPE(1) | BALANCE(S9(10)V99) | STATUS(1) | OPEN-DATE(8) | LAST-ACTIVITY(8)`

**TRANSREC** (103 bytes): `TRANS-ID(12) | ACCT-ID(10) | TYPE(1) | AMOUNT(S9(10)V99) | DATE(8) | TIME(6) | DESC(40) | STATUS(2) | BATCH-ID(12)`

**OUTBOUND** (pipe-delimited): `SOURCE-ACCT|DEST-ACCT|AMOUNT|DESC|DAY`

## Data Layout

```
data/
├── BANK_A/    8 accounts (ACT-A-001..008)
├── BANK_B/    7 accounts (ACT-B-001..007)
├── BANK_C/    8 accounts (ACT-C-001..008)
├── BANK_D/    6 accounts (ACT-D-001..006)
├── BANK_E/    8 accounts (ACT-E-001..008)
└── CLEARING/  5 nostro   (NST-BANK-A..E, $10M each)
```

## Status Codes

| Code | Meaning |
|------|---------|
| 00 | Success |
| 01 | Insufficient funds (NSF) |
| 02 | Daily limit exceeded |
| 03 | Invalid account |
| 04 | Account frozen |
| 99 | System error |

## Requirements

- GnuCOBOL 3.x+ (`cobc`)
- Bash shell
- No other dependencies

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for documented bugs, limitations, and production fixes.
