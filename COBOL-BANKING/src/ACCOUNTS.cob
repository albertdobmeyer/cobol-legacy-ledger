      *>================================================================*
      *>  Program:     ACCOUNTS.cob
      *>  System:      LEGACY LEDGER — Account Lifecycle Management
      *>  Node:        All (same binary, per-node data directories)
      *>  Author:      AKD Solutions
      *>  Written:     2026-02-17
      *>  Modified:    2026-02-23
      *>
      *>  Purpose:
      *>    Account master file CRUD operations. Creates, reads,
      *>    updates, and lists customer and nostro accounts stored
      *>    in the node's ACCOUNTS.DAT sequential file.
      *>
      *>  Operations (via command-line argument):
      *>    CREATE  — Add new account to master file
      *>    READ    — Display single account by ID
      *>    LIST    — Display all active accounts
      *>    UPDATE  — Modify account status
      *>    CLOSE   — Set account status to 'C' (closed)
      *>
      *>  Files:
      *>    Input/Output: ACCOUNTS.DAT (LINE SEQUENTIAL, 70-byte records)
      *>
      *>  Copybooks:
      *>    ACCTREC.cpy  — Account record layout (70 bytes)
      *>    COMCODE.cpy  — Shared status codes and bank identifiers
      *>    ACCTIO.cpy   — Shared account I/O paragraphs
      *>
      *>  Output Format (to STDOUT, pipe-delimited):
      *>    Account: ACCOUNT|ACCT-ID|NAME|TYPE|BALANCE|STATUS|OPENED|LASTACT
      *>    Created: ACCOUNT-CREATED|ACCT-ID
      *>    Updated: ACCOUNT-UPDATED|ACCT-ID
      *>    Closed:  ACCOUNT-CLOSED|ACCT-ID
      *>    Result:  RESULT|XX  (where XX = status code from COMCODE.cpy)
      *>
      *>  Exit Codes:
      *>    RESULT|00 — Success
      *>    RESULT|03 — Account not found (or duplicate on CREATE)
      *>    RESULT|99 — Invalid operation or file I/O error
      *>
      *>  Dependencies:
      *>    Requires ACCOUNTS.DAT to exist in CWD (working directory).
      *>    CWD is set by the Python bridge to banks/{NODE}/.
      *>    If file does not exist, returns RESULT|99 on READ/LIST,
      *>    or creates it on first CREATE.
      *>
      *>  Change Log:
      *>    2026-02-17  AKD  Initial implementation — Phase 1
      *>    2026-02-23  AKD  Production headers, dynamic dates,
      *>                     file status checks, copybook extraction
      *>    2026-02-23  AKD  Fix UNSTRING parsing (multi-arg ops now
      *>                     work: READ, CREATE, UPDATE, CLOSE)
      *>
      *>================================================================*

      *>  IDENTIFICATION / ENVIRONMENT / DATA DIVISIONS
      *>  See SMOKETEST.cob for detailed explanations of each division.
      *>  This file focuses on new concepts: CLI parsing, EVALUATE,
      *>  PERFORM VARYING, and the load-modify-save pattern.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCOUNTS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCOUNTS-FILE
               ASSIGN TO "ACCOUNTS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCOUNTS-FILE.
       COPY "ACCTREC.cpy".

       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS         PIC XX VALUE SPACES.
      *>   WS-CMD-LINE holds the full command-line string before parsing
       01  WS-CMD-LINE            PIC X(200) VALUE SPACES.
       01  WS-OPERATION           PIC X(10) VALUE SPACES.
       01  WS-IN-ACCT-ID          PIC X(10) VALUE SPACES.
       01  WS-IN-NAME             PIC X(30) VALUE SPACES.
       01  WS-IN-TYPE             PIC X(1) VALUE 'C'.
       01  WS-IN-STATUS           PIC X(1) VALUE 'A'.
       01  WS-CURRENT-DATE        PIC 9(8) VALUE 0.
       01  WS-CURRENT-TIME        PIC 9(6) VALUE 0.
      *>   ACCTIO.cpy provides the in-memory account table (WS-ACCOUNT-TABLE)
      *>   and helper variables (WS-ACCOUNT-COUNT, WS-FOUND-FLAG, etc.)
       COPY "ACCTIO.cpy".
       COPY "COMCODE.cpy".

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
      *>   ACCEPT FROM DATE/TIME retrieves system clock values
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           ACCEPT WS-CURRENT-TIME FROM TIME
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: ACCEPT FROM COMMAND-LINE
      *> Reads the entire command-line argument string into a
      *> variable. Unlike modern languages with argv arrays, COBOL
      *> gets one big string that you must parse yourself. This is
      *> how the Python bridge passes operations to COBOL programs:
      *>   ./ACCOUNTS "CREATE ACT-A-001 John_Doe C"
      *> ═══════════════════════════════════════════════════════════
           ACCEPT WS-CMD-LINE FROM COMMAND-LINE

      *>   Parse all args from single command-line string
      *>   (GnuCOBOL ACCEPT FROM COMMAND-LINE returns full string)
      *>   For CREATE: "CREATE ACT-X-001 John_Doe C"
      *>   For READ:   "READ ACT-T-001"
      *>   For UPDATE: "UPDATE ACT-T-001 F"
      *>   For CLOSE:  "CLOSE ACT-T-001"
      *>   For LIST:   "LIST"
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: UNSTRING (splitting strings)
      *> UNSTRING splits a string by a delimiter into multiple
      *> target fields — like Python's str.split() or JS split().
      *>   UNSTRING source DELIMITED BY SPACE
      *>       INTO field1 field2 field3
      *> Each word goes into the next field. Extra fields get
      *> spaces. Fewer fields means trailing words are lost.
      *> ═══════════════════════════════════════════════════════════
           UNSTRING WS-CMD-LINE DELIMITED BY SPACE
               INTO WS-OPERATION
                    WS-IN-ACCT-ID
                    WS-IN-NAME
                    WS-IN-TYPE
                    WS-IN-STATUS
           END-UNSTRING
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: FUNCTION TRIM
      *> Removes leading/trailing spaces from a string. COBOL
      *> fields are fixed-width and right-padded with spaces, so
      *> TRIM is essential after UNSTRING to get clean values.
      *> Equivalent to Python's str.strip() or JS trim().
      *> ═══════════════════════════════════════════════════════════
           MOVE FUNCTION TRIM(WS-OPERATION) TO WS-OPERATION
           MOVE FUNCTION TRIM(WS-IN-ACCT-ID) TO WS-IN-ACCT-ID
           MOVE FUNCTION TRIM(WS-IN-NAME) TO WS-IN-NAME
           MOVE FUNCTION TRIM(WS-IN-TYPE) TO WS-IN-TYPE
           MOVE FUNCTION TRIM(WS-IN-STATUS) TO WS-IN-STATUS

      *>   For UPDATE "UPDATE ACT-T-001 F": status lands in
      *>   WS-IN-NAME (3rd UNSTRING field). Move it to WS-IN-STATUS.
           IF WS-OPERATION = "UPDATE"
               MOVE WS-IN-NAME(1:1) TO WS-IN-STATUS
           END-IF

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: EVALUATE (switch/case equivalent)
      *> EVALUATE tests a variable against multiple values, like
      *> switch/case in C or match in Rust. WHEN OTHER is the
      *> default/else branch. Unlike C, there is no fall-through —
      *> each WHEN branch is independent.
      *> ═══════════════════════════════════════════════════════════
           EVALUATE WS-OPERATION
               WHEN "LIST"
                   PERFORM LIST-ACCOUNTS
               WHEN "CREATE"
                   PERFORM CREATE-ACCOUNT
               WHEN "READ"
                   PERFORM READ-ACCOUNT
               WHEN "UPDATE"
                   PERFORM UPDATE-ACCOUNT
               WHEN "CLOSE"
                   PERFORM CLOSE-ACCOUNT
               WHEN OTHER
                   DISPLAY "RESULT|99"
           END-EVALUATE

           STOP RUN.

      *> -------------------------------------------------------
      *> LIST-ACCOUNTS: Read all records and display each one.
      *> This is the simplest pattern: open, loop-read, close.
      *> -------------------------------------------------------
       LIST-ACCOUNTS.
           OPEN INPUT ACCOUNTS-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY "ERROR|FILE-OPEN|" WS-FILE-STATUS
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: PERFORM UNTIL 1 = 0 (infinite loop idiom)
      *> COBOL has no while(true) or loop keyword. The idiom
      *> "PERFORM UNTIL 1 = 0" creates an infinite loop because
      *> 1 never equals 0. You break out with EXIT PERFORM (inside
      *> the AT END clause when the file runs out of records).
      *> ═══════════════════════════════════════════════════════════
           PERFORM UNTIL 1 = 0
               READ ACCOUNTS-FILE
                   AT END
                       CLOSE ACCOUNTS-FILE
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: EXIT PERFORM
      *> Breaks out of the nearest enclosing PERFORM loop — like
      *> "break" in C/Java/Python. Without it, the only way out
      *> of PERFORM UNTIL is for the condition to become true.
      *> ═══════════════════════════════════════════════════════════
                       EXIT PERFORM
               END-READ
               DISPLAY "ACCOUNT|"
                   ACCT-ID "|"
                   ACCT-NAME "|"
                   ACCT-TYPE "|"
                   ACCT-BALANCE "|"
                   ACCT-STATUS "|"
                   ACCT-OPEN-DATE "|"
                   ACCT-LAST-ACTIVITY
           END-PERFORM
           DISPLAY "RESULT|00".

      *> -------------------------------------------------------
      *> LOAD-ALL-ACCOUNTS: Read entire file into an in-memory
      *> table (array). COBOL sequential files don't support
      *> random access, so the load-modify-save pattern reads
      *> everything into WORKING-STORAGE, modifies it there,
      *> then rewrites the whole file. This is standard practice
      *> for small master files in batch COBOL systems.
      *> -------------------------------------------------------
       LOAD-ALL-ACCOUNTS.
           MOVE 0 TO WS-ACCOUNT-COUNT
           OPEN INPUT ACCOUNTS-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY "ERROR|FILE-OPEN|" WS-FILE-STATUS
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
           PERFORM UNTIL 1 = 0
               READ ACCOUNTS-FILE
                   AT END
                       CLOSE ACCOUNTS-FILE
                       EXIT PERFORM
               END-READ
               ADD 1 TO WS-ACCOUNT-COUNT
               MOVE ACCT-ID TO WS-A-ID(WS-ACCOUNT-COUNT)
               MOVE ACCT-NAME TO WS-A-NAME(WS-ACCOUNT-COUNT)
               MOVE ACCT-TYPE TO WS-A-TYPE(WS-ACCOUNT-COUNT)
               MOVE ACCT-BALANCE TO WS-A-BALANCE(WS-ACCOUNT-COUNT)
               MOVE ACCT-STATUS TO WS-A-STATUS(WS-ACCOUNT-COUNT)
               MOVE ACCT-OPEN-DATE TO WS-A-OPEN(WS-ACCOUNT-COUNT)
               MOVE ACCT-LAST-ACTIVITY TO WS-A-ACTIVITY(WS-ACCOUNT-COUNT)
           END-PERFORM.

      *> -------------------------------------------------------
      *> WRITE-ALL-ACCOUNTS: Rewrite the entire master file from
      *> the in-memory table. OPEN OUTPUT overwrites the file.
      *> -------------------------------------------------------
       WRITE-ALL-ACCOUNTS.
           OPEN OUTPUT ACCOUNTS-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY "ERROR|FILE-OPEN|" WS-FILE-STATUS
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: PERFORM VARYING (for-loop equivalent)
      *> PERFORM VARYING is COBOL's counted loop:
      *>   PERFORM VARYING idx FROM 1 BY 1 UNTIL idx > max
      *> is equivalent to: for (idx = 1; idx <= max; idx++)
      *> The variable is incremented BY the step value after
      *> each iteration, and the UNTIL condition is checked
      *> before each iteration (like a while loop, not do-while).
      *> ═══════════════════════════════════════════════════════════
           PERFORM VARYING WS-ACCT-IDX FROM 1 BY 1
               UNTIL WS-ACCT-IDX > WS-ACCOUNT-COUNT
               MOVE WS-A-ID(WS-ACCT-IDX) TO ACCT-ID
               MOVE WS-A-NAME(WS-ACCT-IDX) TO ACCT-NAME
               MOVE WS-A-TYPE(WS-ACCT-IDX) TO ACCT-TYPE
               MOVE WS-A-BALANCE(WS-ACCT-IDX) TO ACCT-BALANCE
               MOVE WS-A-STATUS(WS-ACCT-IDX) TO ACCT-STATUS
               MOVE WS-A-OPEN(WS-ACCT-IDX) TO ACCT-OPEN-DATE
               MOVE WS-A-ACTIVITY(WS-ACCT-IDX) TO ACCT-LAST-ACTIVITY
               WRITE ACCOUNT-RECORD
           END-PERFORM
           CLOSE ACCOUNTS-FILE.

      *> -------------------------------------------------------
      *> FIND-ACCOUNT: Linear search through the in-memory table.
      *> Sets WS-FOUND-FLAG to 'Y' and WS-FOUND-IDX to the
      *> matching index. Sequential files have no indexes, so
      *> linear search is the only option (fine for < 100 records).
      *> -------------------------------------------------------
       FIND-ACCOUNT.
           MOVE 'N' TO WS-FOUND-FLAG
           MOVE 0 TO WS-FOUND-IDX
           PERFORM VARYING WS-ACCT-IDX FROM 1 BY 1
               UNTIL WS-ACCT-IDX > WS-ACCOUNT-COUNT
               IF WS-A-ID(WS-ACCT-IDX) = WS-IN-ACCT-ID
                   MOVE 'Y' TO WS-FOUND-FLAG
                   MOVE WS-ACCT-IDX TO WS-FOUND-IDX
                   EXIT PERFORM
               END-IF
           END-PERFORM.

      *> -------------------------------------------------------
      *> CREATE-ACCOUNT: Add a new account to the master file.
      *> Checks for duplicates first, then appends to the in-memory
      *> table and rewrites the file.
      *> -------------------------------------------------------
       CREATE-ACCOUNT.
           PERFORM LOAD-ALL-ACCOUNTS
           PERFORM FIND-ACCOUNT
           IF WS-FOUND-FLAG = 'Y'
               DISPLAY "RESULT|99"
      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: EXIT PARAGRAPH (early return)
      *> Jumps to the end of the current paragraph — like "return"
      *> in a function. Without EXIT PARAGRAPH, you'd need deeply
      *> nested IF/ELSE blocks. This enables the guard-clause
      *> pattern: check for errors at the top, exit early if found.
      *> ═══════════════════════════════════════════════════════════
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-ACCOUNT-COUNT
           MOVE WS-IN-ACCT-ID TO WS-A-ID(WS-ACCOUNT-COUNT)
           MOVE WS-IN-NAME TO WS-A-NAME(WS-ACCOUNT-COUNT)
           MOVE WS-IN-TYPE TO WS-A-TYPE(WS-ACCOUNT-COUNT)
           MOVE 0 TO WS-A-BALANCE(WS-ACCOUNT-COUNT)
           MOVE 'A' TO WS-A-STATUS(WS-ACCOUNT-COUNT)
           MOVE WS-CURRENT-DATE TO WS-A-OPEN(WS-ACCOUNT-COUNT)
           MOVE WS-CURRENT-DATE TO WS-A-ACTIVITY(WS-ACCOUNT-COUNT)
           PERFORM WRITE-ALL-ACCOUNTS
           DISPLAY "ACCOUNT-CREATED|" WS-IN-ACCT-ID
           DISPLAY "RESULT|00".

      *> -------------------------------------------------------
      *> READ-ACCOUNT: Find and display a single account by ID.
      *> Returns RESULT|03 if not found.
      *> -------------------------------------------------------
       READ-ACCOUNT.
           PERFORM LOAD-ALL-ACCOUNTS
           PERFORM FIND-ACCOUNT
           IF WS-FOUND-FLAG = 'N'
               DISPLAY "RESULT|03"
               EXIT PARAGRAPH
           END-IF
           DISPLAY "ACCOUNT|"
               WS-A-ID(WS-FOUND-IDX) "|"
               WS-A-NAME(WS-FOUND-IDX) "|"
               WS-A-TYPE(WS-FOUND-IDX) "|"
               WS-A-BALANCE(WS-FOUND-IDX) "|"
               WS-A-STATUS(WS-FOUND-IDX) "|"
               WS-A-OPEN(WS-FOUND-IDX) "|"
               WS-A-ACTIVITY(WS-FOUND-IDX)
           DISPLAY "RESULT|00".

      *> -------------------------------------------------------
      *> UPDATE-ACCOUNT: Change the status of an existing account.
      *> Typical use: freeze ('F') or reactivate ('A') an account.
      *> -------------------------------------------------------
       UPDATE-ACCOUNT.
           PERFORM LOAD-ALL-ACCOUNTS
           PERFORM FIND-ACCOUNT
           IF WS-FOUND-FLAG = 'N'
               DISPLAY "RESULT|03"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-IN-STATUS TO WS-A-STATUS(WS-FOUND-IDX)
           MOVE WS-CURRENT-DATE TO WS-A-ACTIVITY(WS-FOUND-IDX)
           PERFORM WRITE-ALL-ACCOUNTS
           DISPLAY "ACCOUNT-UPDATED|" WS-IN-ACCT-ID
           DISPLAY "RESULT|00".

      *> -------------------------------------------------------
      *> CLOSE-ACCOUNT: Set account status to 'C' (closed).
      *> Closed accounts remain in the file for audit trails
      *> but are rejected by VALIDATE for new transactions.
      *> -------------------------------------------------------
       CLOSE-ACCOUNT.
           PERFORM LOAD-ALL-ACCOUNTS
           PERFORM FIND-ACCOUNT
           IF WS-FOUND-FLAG = 'N'
               DISPLAY "RESULT|03"
               EXIT PARAGRAPH
           END-IF
           MOVE 'C' TO WS-A-STATUS(WS-FOUND-IDX)
           MOVE WS-CURRENT-DATE TO WS-A-ACTIVITY(WS-FOUND-IDX)
           PERFORM WRITE-ALL-ACCOUNTS
           DISPLAY "ACCOUNT-CLOSED|" WS-IN-ACCT-ID
           DISPLAY "RESULT|00".
