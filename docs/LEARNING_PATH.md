# Learning Path

A self-study guide for software engineers learning COBOL. Follow the readings in order — each builds on the previous.

**Time estimate**: 6-10 hours total, depending on your pace.

**How to use this guide**: Read each file in order. The educational comments in the source code explain every COBOL concept as it appears. After each section, try the exercises before moving on.

---

## Level 1: Beginner — COBOL Program Structure

*Goal: Understand the skeleton of a COBOL program.*

### Reading 1.1: Your First COBOL Program
**File**: `COBOL-BANKING/src/SMOKETEST.cob`

This is the simplest program in the system — a "hello world" for COBOL file I/O. Read it top to bottom. The comments explain every keyword.

**What you'll learn**:
- The four mandatory divisions (IDENTIFICATION, ENVIRONMENT, DATA, PROCEDURE)
- How files are declared (SELECT/ASSIGN, FD, FILE STATUS)
- How variables are declared (WORKING-STORAGE, PIC clauses)
- How logic is organized (paragraphs, PERFORM)
- Basic I/O (OPEN, READ, WRITE, CLOSE, DISPLAY)

**Exercise**: Without looking at the code, write down the four COBOL divisions in order and describe what each one contains. Check your answer against the file.

### Reading 1.2: Record Layouts — How COBOL Defines Data
**File**: `COBOL-BANKING/copybooks/ACCTREC.cpy`

This is a copybook — a shared file included by multiple programs. It defines the 70-byte account record.

**What you'll learn**:
- PIC X (alphanumeric), PIC 9 (numeric), PIC S9V99 (signed with decimal)
- 88-level condition names (named boolean tests)
- Level numbers (01, 05) and record hierarchy
- How to calculate a record's byte width

**Exercise**: Add up the byte widths of every field in ACCTREC.cpy. Verify the total is 70.

### Reading 1.3: More Record Layouts
**Files**:
1. `COBOL-BANKING/copybooks/TRANSREC.cpy` — Transaction record (103 bytes)
2. `COBOL-BANKING/copybooks/COMCODE.cpy` — Shared constants and status codes

**What you'll learn**:
- Larger record structures with more field types
- How constants are defined in COBOL (01-level groups with VALUE clauses)
- Transaction type codes (D/W/T/I/F) and status codes (00/01/02/03/04/99)

**Exercise**: What PIC clause would you use for a 20-character customer address? What about a dollar amount up to $999,999.99?

---

## Level 2: Intermediate — File I/O and Business Logic

*Goal: Read and understand production-style COBOL programs.*

### Reading 2.1: Account Management
**File**: `COBOL-BANKING/src/ACCOUNTS.cob`

A full CRUD program for account management. This is where you'll see COBOL start to feel like "real" code.

**What you'll learn**:
- ACCEPT FROM COMMAND-LINE (reading CLI arguments)
- UNSTRING (splitting strings — like Python's `split()`)
- EVALUATE (switch/case)
- PERFORM VARYING (for-loops)
- The "load all → find → modify → write all" pattern for sequential files

**Exercise**: Trace the CREATE-ACCOUNT paragraph step by step. What happens if you try to create an account that already exists?

### Reading 2.2: The Shared I/O Pattern
**File**: `COBOL-BANKING/copybooks/ACCTIO.cpy`

This copybook defines the in-memory account table shared across programs.

**What you'll learn**:
- OCCURS clause (COBOL arrays)
- Array subscripting: `WS-A-ID(3)` = 3rd element
- Why COBOL arrays are 1-indexed
- The shared table pattern (data layout in copybook, procedures in each program)

### Reading 2.3: Business Rule Validation
**File**: `COBOL-BANKING/src/VALIDATE.cob`

A pure validation program — read-only, no side effects.

**What you'll learn**:
- The validation pipeline pattern (sequential checks with early exit)
- EXIT PARAGRAPH (early return, like `return` in a function)
- Guard clause pattern in COBOL
- How validation is separated from execution

**Exercise**: VALIDATE.cob checks four things in sequence. List them in order. Why does the order matter?

### Reading 2.4: Transaction Processing
**File**: `COBOL-BANKING/src/TRANSACT.cob`

The largest program — deposits, withdrawals, transfers, and batch processing.

**What you'll learn**:
- ADD/SUBTRACT (arithmetic verbs)
- FUNCTION NUMVAL (string-to-number conversion)
- OPEN EXTEND (append mode)
- STRING (concatenation)
- Batch processing pattern (read → parse → validate → execute → log)
- PIC $$$,$$$,$$9.99 (edited display pictures)

**Exercise**: Trace PROCESS-TRANSFER. Why does it save `WS-FOUND-IDX` to `WS-ACCT-IDX` before searching for the target account? (Hint: see KNOWN_ISSUES.md item T12)

---

## Level 3: Intermediate-Advanced — Reporting and Periodic Processing

*Goal: Understand how COBOL handles reporting, reconciliation, and monthly batch operations.*

### Reading 3.1: Reporting
**File**: `COBOL-BANKING/src/REPORTS.cob`

Four report types, all read-only.

**What you'll learn**:
- Read-only file access pattern (OPEN INPUT, never OUTPUT)
- EVALUATE for multi-branch counting
- Report formatting patterns (header, detail, summary)

### Reading 3.2: Financial Calculations
**File**: `COBOL-BANKING/src/INTEREST.cob`

Monthly interest accrual for savings accounts.

**What you'll learn**:
- COMPUTE (algebraic expressions: `COMPUTE X = Y * Z / 12`)
- ROUNDED (banker's rounding — critical for financial math)
- Why COBOL avoids floating-point

### Reading 3.3: Fee Processing
**File**: `COBOL-BANKING/src/FEES.cob`

Monthly maintenance fees with balance floor protection.

**What you'll learn**:
- Conditional processing (skip if balance too low)
- Balance floor protection pattern
- Monthly batch processing mindset

### Reading 3.4: Reconciliation
**File**: `COBOL-BANKING/src/RECONCILE.cob`

Compares transaction history against account balances.

**What you'll learn**:
- Two-file reconciliation (ACCOUNTS.DAT + TRANSACT.DAT)
- Implied opening balance: `opening = current_balance - net_transactions`
- Match vs. mismatch detection

**Exercise**: If an account has a balance of $5,000 and net transactions of +$3,000, what was the implied opening balance? What would it mean if that value were negative?

---

## Level 4: Advanced — Inter-Bank Communication and Settlement

*Goal: Understand how separate COBOL programs communicate through files and how inter-bank settlement works.*

### Reading 4.1: Simulation Parameters
**File**: `COBOL-BANKING/copybooks/SIMREC.cpy`

Shared working-storage for the simulation and settlement programs.

**What you'll learn**:
- REDEFINES (overlaying memory — like C unions)
- Complex record grouping for multi-program coordination

### Reading 4.2: Transaction Simulation
**File**: `COBOL-BANKING/src/SIMULATE.cob`

Generates deterministic daily transactions for each bank.

**What you'll learn**:
- FUNCTION MOD (modular arithmetic for pseudo-random generation)
- OUTBOUND.DAT pattern (inter-bank communication via file exchange)
- Deterministic simulation (same seed = same results)
- Pipe-delimited output formatting

### Reading 4.3: Clearing House Settlement
**File**: `COBOL-BANKING/src/SETTLE.cob`

The clearing house processes inter-bank transfers.

**What you'll learn**:
- Dynamic file path assignment (`ASSIGN TO` a variable, not a literal)
- 3-leg settlement (debit source nostro, credit dest nostro, write records)
- NSF checking at the clearing house level
- Why banks use nostro accounts

**Exercise**: Draw the 3-leg settlement flow for a $1,000 transfer from BANK_A to BANK_B. Which nostro accounts are affected? What happens to the total nostro balance? (Answer: it doesn't change — settlement is zero-sum)

---

## Level 5: Integration — Python Wrapping Legacy COBOL

*Goal: Understand how modern languages can add capabilities to COBOL without modifying it.*

### Reading 5.1: The Bridge Pattern
**File**: `python/bridge.py`

How Python wraps COBOL as a subprocess.

**What you'll learn**:
- Mode A: subprocess invocation, stdout parsing
- Mode B: Python-native fixed-width file I/O
- SQLite synchronization after every COBOL operation
- Why "wrap, don't modify" is the right approach for legacy systems

### Reading 5.2: Cryptographic Integrity
**File**: `python/integrity.py`

SHA-256 hash chains for tamper detection.

**What you'll learn**:
- How hash chains work (each entry depends on the previous)
- Why modification breaks the chain
- HMAC for authentication
- Chain verification algorithm

### Reading 5.3: Settlement Coordination
**File**: `python/settlement.py`

Multi-node settlement orchestration from Python.

**What you'll learn**:
- 3-step settlement flow across nodes
- Settlement reference tracking
- Error handling across distributed nodes

### Reading 5.4: Cross-Node Verification
**File**: `python/cross_verify.py`

The tamper detection engine.

**What you'll learn**:
- DAT vs SQLite balance comparison
- Settlement matching across chains
- What the system can and cannot detect

### Reading 5.5: The Full Demo
**Run**: `./scripts/prove.sh`

Watch all the pieces work together.

**Exercise**: After running `prove.sh`, manually edit a balance in `COBOL-BANKING/data/BANK_C/ACCOUNTS.DAT` using a text editor. Change any balance to `999999999999`. Then run `python python/cli.py verify --all` and observe the tamper detection.

---

## Quick Reference Card

| COBOL | Python/Java Equivalent |
|-------|----------------------|
| `MOVE X TO Y` | `y = x` |
| `ADD X TO Y` | `y += x` |
| `SUBTRACT X FROM Y` | `y -= x` |
| `COMPUTE X = A * B` | `x = a * b` |
| `PERFORM P` | `p()` (call function) |
| `PERFORM P VARYING I FROM 1 BY 1 UNTIL I > N` | `for i in range(1, n+1): p()` |
| `EVALUATE X WHEN 'A' ... WHEN OTHER ...` | `match x: case 'A': ... case _: ...` |
| `IF ... END-IF` | `if ...:` |
| `UNSTRING X DELIMITED BY "\|" INTO A B C` | `a, b, c = x.split("\|")` |
| `STRING A B INTO C` | `c = a + b` |
| `DISPLAY X` | `print(x)` |
| `ACCEPT X FROM COMMAND-LINE` | `x = sys.argv` |
| `OPEN INPUT F / READ F / CLOSE F` | `f = open(...); f.readline(); f.close()` |
| `PIC X(10)` | `str` (fixed 10 chars) |
| `PIC 9(8)` | `int` (max 8 digits) |
| `PIC S9(10)V99` | `Decimal` (signed, 2 decimal places) |
| `88 IS-ACTIVE VALUE 'A'` | `@property def is_active: return status == 'A'` |
| `COPY "FILE.cpy"` | `from file import *` / `#include "file.h"` |
| `EXIT PERFORM` | `break` |
| `EXIT PARAGRAPH` | `return` (early) |
| `STOP RUN` | `sys.exit()` |
