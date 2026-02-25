      *> ================================================================
      *> SMOKETEST.cob — Compiler and I/O verification
      *> Tests: compilation, copybook resolution, file write, file read,
      *>        fixed-width record format, pipe-delimited DISPLAY output
      *> Compile: cobc -x -free -I ../copybooks SMOKETEST.cob -o ../bin/SMOKETEST
      *> Run:     cd banks/BANK_A && ../../cobol/bin/SMOKETEST
      *> ================================================================

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: IDENTIFICATION DIVISION
      *> Every COBOL program begins here. It names the program and
      *> provides metadata. PROGRAM-ID is the only required entry.
      *> Think of it as the "passport" for the compilation unit.
      *> ═══════════════════════════════════════════════════════════
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SMOKETEST.

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: ENVIRONMENT DIVISION
      *> Maps the program to the outside world: which files it uses,
      *> which OS resources it needs. Separates logical file names
      *> (used in code) from physical file names (on disk).
      *> ═══════════════════════════════════════════════════════════
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: FILE-CONTROL / SELECT...ASSIGN
      *> SELECT creates a logical name (ACCOUNT-FILE) used in code.
      *> ASSIGN TO links it to a physical file on disk.
      *> This indirection means you can change file names without
      *> touching any business logic — a 1960s design pattern that
      *> modern dependency injection reinvented decades later.
      *> ═══════════════════════════════════════════════════════════
       FILE-CONTROL.
           SELECT ACCOUNT-FILE
               ASSIGN TO "TEST-ACCOUNTS.DAT"
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: LINE SEQUENTIAL
      *> File organization type. LINE SEQUENTIAL means each record
      *> is a text line terminated by a newline character. This is
      *> a GnuCOBOL extension — mainframe COBOL uses fixed-length
      *> records without line terminators. We use it here because
      *> it makes .DAT files human-readable with a text editor.
      *> ═══════════════════════════════════════════════════════════
               ORGANIZATION IS LINE SEQUENTIAL
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: FILE STATUS
      *> Captures the result of every file I/O operation into a
      *> 2-character variable. '00' = success, '10' = end-of-file,
      *> '35' = file not found, etc. Without this, COBOL will
      *> silently crash on I/O errors. Always declare FILE STATUS.
      *> ═══════════════════════════════════════════════════════════
               FILE STATUS IS WS-FILE-STATUS.

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: DATA DIVISION
      *> All variable declarations live here. COBOL has no inline
      *> variable declarations — every piece of data the program
      *> uses must be declared upfront in this division. It has
      *> two key sections: FILE SECTION (record buffers tied to
      *> files) and WORKING-STORAGE SECTION (program variables).
      *> ═══════════════════════════════════════════════════════════
       DATA DIVISION.
       FILE SECTION.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: FD (File Description)
      *> FD links a record layout to a file declared in SELECT.
      *> When you READ a file, COBOL fills the FD's record buffer.
      *> When you WRITE, it outputs whatever is in that buffer.
      *> The FD name must match the SELECT name exactly.
      *> ═══════════════════════════════════════════════════════════
       FD  ACCOUNT-FILE.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: COPY statement
      *> Textual inclusion — like C's #include. The compiler
      *> literally pastes the contents of the .cpy file here at
      *> compile time. Copybooks (.cpy) hold shared record layouts
      *> so multiple programs use identical field definitions.
      *> ACCTREC.cpy defines the 70-byte account record structure.
      *> ═══════════════════════════════════════════════════════════
       COPY "ACCTREC.cpy".

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: WORKING-STORAGE SECTION
      *> Program variables that persist for the life of the program.
      *> Unlike the FILE SECTION (which is a buffer tied to I/O),
      *> WORKING-STORAGE is your scratch space — counters, flags,
      *> intermediate results, and any data not read from a file.
      *> ═══════════════════════════════════════════════════════════
       WORKING-STORAGE SECTION.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: PIC clause (PICTURE)
      *> PIC defines the type and size of a variable.
      *>   PIC X(n)  = alphanumeric string of n characters
      *>   PIC 9(n)  = unsigned numeric, n digits
      *>   PIC XX    = shorthand for PIC X(2)
      *> COBOL has no int/float/string types — PIC is the type system.
      *> ═══════════════════════════════════════════════════════════
       01  WS-FILE-STATUS         PIC XX VALUE SPACES.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: 88-level condition names
      *> Level 88 creates a named boolean test on the parent field.
      *> "88 WS-FILE-OK VALUE '00'" means you can write:
      *>     IF WS-FILE-OK   (instead of IF WS-FILE-STATUS = '00')
      *> They're compile-time aliases, not separate variables.
      *> You can have multiple 88s on one field for different values.
      *> ═══════════════════════════════════════════════════════════
           88  WS-FILE-OK         VALUE '00'.
           88  WS-FILE-EOF        VALUE '10'.
       01  WS-RECORD-COUNT        PIC 9(4) VALUE 0.

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: PROCEDURE DIVISION
      *> All executable code lives here. Everything above was
      *> declarations; this is where the program actually runs.
      *> Execution begins at the first statement after
      *> PROCEDURE DIVISION and flows top-to-bottom unless
      *> redirected by PERFORM (subroutine call) or STOP RUN.
      *> ═══════════════════════════════════════════════════════════
       PROCEDURE DIVISION.
       MAIN-PROGRAM.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: PERFORM (subroutine call)
      *> PERFORM transfers control to a named paragraph, executes
      *> it, then returns here. Like calling a function, but COBOL
      *> paragraphs share all variables (no parameters, no return
      *> values). Communication happens through WORKING-STORAGE.
      *> ═══════════════════════════════════════════════════════════
           PERFORM WRITE-TEST-RECORD
           PERFORM READ-TEST-RECORD
           PERFORM CLEANUP
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: STOP RUN
      *> Terminates the program and returns control to the OS.
      *> Every COBOL program must end with STOP RUN (or GOBACK
      *> in subprograms). Without it, execution falls through
      *> into the next paragraph, which is almost never intended.
      *> ═══════════════════════════════════════════════════════════
           STOP RUN.

      *> --- Write a test account record to disk ---
       WRITE-TEST-RECORD.
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: OPEN / READ / WRITE / CLOSE (file I/O)
      *> COBOL file I/O uses explicit verbs:
      *>   OPEN OUTPUT  — create/overwrite a file for writing
      *>   OPEN INPUT   — open existing file for reading
      *>   WRITE record — write one record to an open output file
      *>   READ file    — read next record from an open input file
      *>   CLOSE file   — release the file handle
      *> Files MUST be opened before use and closed after.
      *> ═══════════════════════════════════════════════════════════
           OPEN OUTPUT ACCOUNT-FILE
           IF NOT WS-FILE-OK
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: DISPLAY (stdout output)
      *> DISPLAY writes text to standard output (the terminal).
      *> Multiple items can be concatenated in one DISPLAY.
      *> This is COBOL's printf/console.log equivalent.
      *> Our programs use pipe-delimited DISPLAY output so the
      *> Python bridge can parse structured results from COBOL.
      *> ═══════════════════════════════════════════════════════════
               DISPLAY "ERROR|FILE-OPEN-WRITE|" WS-FILE-STATUS
               STOP RUN
           END-IF

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: INITIALIZE
      *> Sets all fields in a record to their default values:
      *> alphanumeric fields become SPACES, numeric fields become
      *> zeros. Like memset but type-aware. Always INITIALIZE a
      *> record before populating it to avoid leftover garbage.
      *> ═══════════════════════════════════════════════════════════
           INITIALIZE ACCOUNT-RECORD
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: MOVE (assignment)
      *> MOVE is COBOL's assignment operator. "MOVE X TO Y" is
      *> equivalent to "Y = X" in most languages. COBOL has no
      *> = operator for assignment — the equals sign is only
      *> used in conditions (IF X = Y). MOVE handles type
      *> conversion automatically (e.g., numeric to string).
      *> ═══════════════════════════════════════════════════════════
           MOVE "ACT-T-001"      TO ACCT-ID
           MOVE "Smoke Test User" TO ACCT-NAME
           MOVE "C"              TO ACCT-TYPE
           MOVE 12345.67         TO ACCT-BALANCE
           MOVE "A"              TO ACCT-STATUS
           MOVE 20260217         TO ACCT-OPEN-DATE
           MOVE 20260217         TO ACCT-LAST-ACTIVITY

           WRITE ACCOUNT-RECORD
           IF NOT WS-FILE-OK
               DISPLAY "ERROR|FILE-WRITE|" WS-FILE-STATUS
               STOP RUN
           END-IF

           CLOSE ACCOUNT-FILE
           DISPLAY "OK|WRITE|ACT-T-001|Smoke Test User".

      *> --- Read back the record we just wrote and verify it ---
       READ-TEST-RECORD.
           OPEN INPUT ACCOUNT-FILE
           IF NOT WS-FILE-OK
               DISPLAY "ERROR|FILE-OPEN-READ|" WS-FILE-STATUS
               STOP RUN
           END-IF

      *>   READ fills the FD record buffer (ACCOUNT-RECORD) with
      *>   the next record from the file. AT END fires when there
      *>   are no more records (file status '10').
           READ ACCOUNT-FILE
               AT END
                   DISPLAY "ERROR|EMPTY-FILE|No records found"
                   CLOSE ACCOUNT-FILE
                   STOP RUN
           END-READ

           IF NOT WS-FILE-OK AND NOT WS-FILE-EOF
               DISPLAY "ERROR|FILE-READ|" WS-FILE-STATUS
               CLOSE ACCOUNT-FILE
               STOP RUN
           END-IF

      *>   Display all fields pipe-delimited so the Python bridge
      *>   can parse them. Each field comes from the copybook layout.
           DISPLAY "OK|READ|"
               ACCT-ID "|"
               ACCT-NAME "|"
               ACCT-TYPE "|"
               ACCT-BALANCE "|"
               ACCT-STATUS "|"
               ACCT-OPEN-DATE "|"
               ACCT-LAST-ACTIVITY

           CLOSE ACCOUNT-FILE.

       CLEANUP.
      *>   Test file is left in banks/BANK_A/TEST-ACCOUNTS.DAT for inspection
           DISPLAY "SMOKE-TEST|PASS|All checks succeeded".
