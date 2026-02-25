# Glossary

COBOL, banking, and project-specific terms used in this codebase.

---

## COBOL Terms

### 88-Level Condition Name
A special data item that defines a named boolean condition on its parent field. Instead of writing `IF ACCT-STATUS = 'A'`, you write `IF ACCT-ACTIVE`. Defined with `88 ACCT-ACTIVE VALUE 'A'.` under the parent field. See `ACCTREC.cpy`.

### ACCEPT
Verb that reads external input into a variable. `ACCEPT X FROM COMMAND-LINE` reads CLI arguments. `ACCEPT X FROM DATE YYYYMMDD` reads the system date. See `ACCOUNTS.cob`.

### ADD / SUBTRACT
Arithmetic verbs. COBOL uses English words instead of operators: `ADD X TO Y` instead of `y += x`. `SUBTRACT X FROM Y` instead of `y -= x`. See `TRANSACT.cob`.

### ASSIGN TO
Part of the `SELECT ... ASSIGN TO` clause in FILE-CONTROL. Maps a logical file name to a physical filename on disk. `ASSIGN TO "ACCOUNTS.DAT"` means this program reads/writes `ACCOUNTS.DAT` in the current working directory. See `ACCOUNTS.cob`.

### CLOSE
Verb that releases a file after reading or writing. Every `OPEN` must have a matching `CLOSE`. Leaving files open can corrupt data. See `SMOKETEST.cob`.

### COMPUTE
Arithmetic verb that allows algebraic expressions: `COMPUTE X = (A * B) / C`. More concise than chaining ADD/SUBTRACT/MULTIPLY/DIVIDE. See `INTEREST.cob`.

### COPY
Preprocessor directive that includes a copybook file inline, similar to C's `#include`. `COPY "ACCTREC.cpy"` pastes the account record layout into the current program at compile time. See every `.cob` file.

### Copybook
A shared source file (`.cpy` extension) containing record layouts, constants, or common working-storage definitions. Included via the `COPY` statement. Equivalent to header files in C. See `COBOL-BANKING/copybooks/`.

### DATA DIVISION
The third of four COBOL divisions. Declares all variables, file record layouts, and working storage. COBOL has no inline variable declarations — everything is declared here before the PROCEDURE DIVISION. See `SMOKETEST.cob`.

### DISPLAY
Verb that writes text to standard output (stdout). Used for all program output in this system. Output is pipe-delimited for machine parsing by the Python bridge. See `SMOKETEST.cob`.

### Division
COBOL programs are organized into four divisions, always in this order:
1. **IDENTIFICATION DIVISION** — Program metadata (name, author)
2. **ENVIRONMENT DIVISION** — External resource mapping (files, devices)
3. **DATA DIVISION** — All variable and record declarations
4. **PROCEDURE DIVISION** — Executable logic (the actual program)

### ENVIRONMENT DIVISION
The second division. Maps logical names to physical resources. The INPUT-OUTPUT SECTION / FILE-CONTROL paragraph defines which files the program uses. See `ACCOUNTS.cob`.

### EVALUATE
COBOL's switch/case equivalent. `EVALUATE X WHEN 'A' ... WHEN 'B' ... WHEN OTHER ...` is like `switch(x) { case 'A': ... case 'B': ... default: ... }`. See `TRANSACT.cob`.

### EXIT PARAGRAPH
Early return from the current paragraph. Equivalent to `return` in the middle of a function. Used for guard clauses and validation pipelines. See `VALIDATE.cob`.

### EXIT PERFORM
Break out of the innermost `PERFORM` loop. Equivalent to `break` in C/Java/Python. See `ACCOUNTS.cob`.

### FD (File Description)
Declares a file's record layout in the FILE SECTION of the DATA DIVISION. Links the logical file (from SELECT) to its record structure. `FD ACCOUNTS-FILE.` followed by `COPY "ACCTREC.cpy"` defines the 70-byte account record. See `SMOKETEST.cob`.

### FILE-CONTROL
A paragraph in the ENVIRONMENT DIVISION's INPUT-OUTPUT SECTION. Contains `SELECT ... ASSIGN TO` entries that map logical file names to physical files. See `ACCOUNTS.cob`.

### FILE SECTION
Part of the DATA DIVISION that contains FD entries. Defines record buffers — when you `READ`, data lands in these buffers. See `SMOKETEST.cob`.

### FILE STATUS
A 2-character variable that receives the result code after every file operation. `'00'` = success, `'10'` = end-of-file, anything else = error. Declared with `FILE STATUS IS WS-FILE-STATUS` in SELECT. See `SMOKETEST.cob`.

### FUNCTION MOD
Intrinsic function for modular arithmetic. `FUNCTION MOD(X, Y)` returns the remainder of X / Y. Used for pseudo-random number generation in `SIMULATE.cob`.

### FUNCTION NUMVAL
Intrinsic function that converts a string to a numeric value. `FUNCTION NUMVAL("123.45")` returns `123.45`. Necessary because COBOL's `MOVE` doesn't auto-convert strings to numbers. See `TRANSACT.cob`.

### FUNCTION TRIM
Intrinsic function that removes leading/trailing spaces. Essential because COBOL fields are fixed-width and always space-padded. See `ACCOUNTS.cob`.

### IDENTIFICATION DIVISION
The first division. Contains `PROGRAM-ID` (the program's name) and optional metadata (AUTHOR, DATE-WRITTEN). See every `.cob` file.

### Implied Decimal (V)
In PIC clauses, `V` marks the decimal point position without storing an actual `.` character. `PIC 9(10)V99` stores 12 digits where the last 2 are cents. The value `$5,000.00` is stored as `000000500000`. See `ACCTREC.cpy`.

### INITIALIZE
Verb that resets a group item (record) to its default values — spaces for alphanumeric fields, zeros for numeric fields. Like calling a zero-fill constructor. See `SMOKETEST.cob`.

### LINE SEQUENTIAL
File organization where records are separated by line breaks (newlines). This is the simplest file format — each line is one record. Alternative is RECORD SEQUENTIAL (fixed-length blocks with no line breaks). This project uses LINE SEQUENTIAL throughout. See `SMOKETEST.cob`.

### MOVE
Assignment verb. `MOVE X TO Y` copies the value of X into Y (like `y = x`). COBOL has no `=` assignment operator — all assignments use MOVE. See `SMOKETEST.cob`.

### OCCURS
Declares an array (table) in COBOL. `OCCURS 100 TIMES` creates 100 copies of the subordinate fields. Accessed by subscript: `WS-A-ID(3)` is the 3rd element. COBOL arrays are 1-indexed. See `ACCTIO.cpy`.

### OPEN
Verb that prepares a file for reading or writing. Modes: `OPEN INPUT` (read-only), `OPEN OUTPUT` (write, truncates existing), `OPEN EXTEND` (append). See `SMOKETEST.cob`.

### Paragraph
A named block of executable code in the PROCEDURE DIVISION. Called with `PERFORM paragraph-name`. Equivalent to a function/method, but COBOL paragraphs share the same scope — all variables are global. See `SMOKETEST.cob`.

### PERFORM
Verb that calls a paragraph (subroutine). `PERFORM X` calls paragraph X and returns. `PERFORM X VARYING I FROM 1 BY 1 UNTIL I > N` is a for-loop. `PERFORM UNTIL condition` is a while-loop. See `ACCOUNTS.cob`.

### PIC (PICTURE) Clause
Defines a field's data type and size:
- `PIC X(10)` — 10 alphanumeric characters (like `char[10]`)
- `PIC 9(8)` — 8-digit unsigned integer
- `PIC S9(10)V99` — Signed 10-digit integer with 2 implied decimal places
- `PIC $$$,$$$,$$9.99` — Edited numeric for display formatting

See `ACCTREC.cpy` for annotated examples.

### PROCEDURE DIVISION
The fourth and final division. Contains all executable logic organized into paragraphs. This is where the program runs. See `SMOKETEST.cob`.

### READ
Verb that reads the next record from a sequential file into the file's record buffer (defined by the FD). `AT END` clause handles end-of-file. See `SMOKETEST.cob`.

### REDEFINES
Overlays the same physical memory with a different field layout. Like a C `union`. `WS-AMT-REDEF REDEFINES WS-AMT-DISPLAY` lets you access the same bytes as either a single field or multiple sub-fields. See `SIMREC.cpy`.

### ROUNDED
Modifier on arithmetic verbs that applies standard rounding (banker's rounding). `COMPUTE X ROUNDED = Y / Z` prevents silent truncation of decimal places. Critical for financial calculations. See `INTEREST.cob`.

### Section
A grouping of related paragraphs in the PROCEDURE DIVISION, or a grouping of related declarations in other divisions (e.g., FILE SECTION, WORKING-STORAGE SECTION). Sections contain paragraphs; paragraphs contain statements.

### SELECT
Part of FILE-CONTROL that declares a logical file name and its properties. `SELECT ACCOUNTS-FILE ASSIGN TO "ACCOUNTS.DAT" ORGANIZATION IS LINE SEQUENTIAL FILE STATUS IS WS-FILE-STATUS` maps the logical name `ACCOUNTS-FILE` to the physical file `ACCOUNTS.DAT`. See `ACCOUNTS.cob`.

### STOP RUN
Terminates the program immediately. Returns control to the operating system (or the calling process — in this project, the Python bridge). See `SMOKETEST.cob`.

### STRING
Concatenation verb. `STRING X DELIMITED SIZE Y DELIMITED SIZE INTO Z` concatenates X and Y into Z. `DELIMITED SIZE` means use the full field; `DELIMITED SPACE` means stop at the first space. See `TRANSACT.cob`.

### UNSTRING
String-splitting verb. `UNSTRING X DELIMITED BY "|" INTO A B C` splits X at pipe characters into fields A, B, C. Like `split("|")` in Python/Java. See `ACCOUNTS.cob`.

### WORKING-STORAGE SECTION
Part of the DATA DIVISION that declares program variables. Unlike the FILE SECTION (which defines I/O buffers), WORKING-STORAGE holds variables that persist for the program's lifetime. All variables are global to the program. See `SMOKETEST.cob`.

### WRITE
Verb that writes the current record buffer to a file. The data to write must already be in the FD's record area (populated via MOVE statements). See `SMOKETEST.cob`.

---

## Banking Terms

### Batch Processing
Processing a group of transactions together as a unit, typically from a file. In this system, `BATCH-INPUT.DAT` contains pipe-delimited transaction records that TRANSACT.cob processes sequentially. Banks traditionally process batches overnight (EOD batch runs).

### Clearing House
A central intermediary that facilitates settlement between banks. In this system, the CLEARING node holds nostro accounts for each bank and processes inter-bank transfers. Real-world examples: Federal Reserve (Fedwire), SWIFT, ACH.

### CTR (Currency Transaction Report)
A regulatory filing required for cash transactions over $10,000. This system flags deposits within $500 of the threshold as a compliance note — a pattern called "structuring detection." See `TRANSACT.cob`.

### EOD (End of Day)
The daily reconciliation process where a bank tallies all transactions, verifies balances, and produces summary reports. See `REPORTS.cob` (EOD operation).

### Ledger
The authoritative record of all financial transactions. In COBOL banking, the ledger is the combination of `ACCOUNTS.DAT` (balances) and `TRANSACT.DAT` (transaction history).

### Nostro Account
An account that a bank holds at another institution — literally "our money at their bank" (from Italian "nostro" = ours). In this system, each bank has a nostro account at the clearing house (e.g., `NST-BANK-A`). Settlement moves money between nostro accounts. See `SETTLE.cob`.

### NSF (Non-Sufficient Funds)
A transaction rejection when the account balance is too low to cover the withdrawal or transfer amount. Status code `01` in this system.

### Reconciliation
The process of comparing two sets of records to ensure they agree. In this system: (1) RECONCILE.cob compares transaction history against account balances, (2) the Python cross-verifier compares DAT file balances against SQLite snapshots. Discrepancies indicate errors or tampering.

### Settlement
The process of actually moving money between banks to fulfill inter-bank transfer obligations. In this system, settlement is a 3-step process: debit source bank's nostro, credit destination bank's nostro, record both sides. See `python/settlement.py`.

### Settlement Reference
A unique identifier for a settlement transaction (`STL-YYYYMMDD-NNNNNN`). Used by the cross-node verifier to match entries across all chains — if bank A shows a debit and the clearing house shows the matching credit, the settlement is confirmed.

---

## Project-Specific Terms

### Bridge Pattern
The Python wrapper (`bridge.py`) that sits between the CLI/API layer and the COBOL programs. It handles subprocess invocation, output parsing, SQLite synchronization, and integrity chain recording. The bridge never modifies COBOL — it only observes.

### Chain Entry
A single record in the SHA-256 hash chain, stored in SQLite. Contains: transaction data, timestamp, previous hash, and computed hash. The chain is append-only — entries cannot be modified or deleted without breaking the chain.

### DAT File
COBOL fixed-width data files (`ACCOUNTS.DAT`, `TRANSACT.DAT`). Each record is a fixed number of bytes (70 for accounts, 103 for transactions). Fields are positional — character 1-10 is the account ID, 11-40 is the name, etc. No delimiters, no headers.

### Hash Chain
An append-only sequence of records where each record's hash depends on the previous record's hash. If any record is modified, all subsequent hashes become invalid. This system uses SHA-256. See `python/integrity.py`.

### Mode A (COBOL Mode)
The production execution path. Python calls compiled COBOL binaries as subprocesses, passing operations via command-line arguments. COBOL reads/writes DAT files directly. Python parses the pipe-delimited stdout for results.

### Mode B (Python Fallback)
The fallback execution path when GnuCOBOL isn't installed. Python reads/writes the same fixed-width DAT files directly, applying identical business rules. Used in CI pipelines, dev machines, and environments without a COBOL compiler.

### Node
One of the 6 independent banking entities in the system: BANK_A, BANK_B, BANK_C, BANK_D, BANK_E, or CLEARING. Each node has its own data directory, SQLite database, and hash chain. Nodes communicate only through file exchange (OUTBOUND.DAT) and the settlement coordinator.

### Tamper Detection
The system's ability to detect unauthorized modifications to data files. Two layers: (1) hash chain verification catches modified chain entries, (2) balance reconciliation catches direct DAT file edits that bypass the chain entirely.
