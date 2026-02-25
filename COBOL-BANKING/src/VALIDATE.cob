      *>================================================================*
      *>  Program:     VALIDATE.cob
      *>  System:      LEGACY LEDGER — Business Rules & Validation
      *>  Node:        All (same binary, per-node data directories)
      *>  Author:      AKD Solutions
      *>  Written:     2026-02-17
      *>  Modified:    2026-02-23
      *>
      *>  Purpose:
      *>    Pre-transaction validation of business rules. Checks
      *>    account existence, account status (active/frozen), balance
      *>    sufficiency, and daily withdrawal limits. Called by the
      *>    Python bridge before debit operations.
      *>
      *>  Operations:
      *>    Single validation pass: account_id + amount via CLI args
      *>    Sequence: exists → active → balance → daily limit
      *>
      *>  Files:
      *>    Input: ACCOUNTS.DAT (LINE SEQUENTIAL, 70-byte records)
      *>
      *>  Copybooks:
      *>    ACCTREC.cpy  — Account record layout (70 bytes)
      *>    COMCODE.cpy  — Shared status codes and bank identifiers
      *>    ACCTIO.cpy   — Shared account I/O paragraphs
      *>
      *>  Output Format (to STDOUT):
      *>    Result: RESULT|XX  (where XX = status code)
      *>
      *>  Exit Codes:
      *>    RESULT|00 — All checks pass
      *>    RESULT|01 — Insufficient funds
      *>    RESULT|02 — Daily limit exceeded
      *>    RESULT|03 — Account not found
      *>    RESULT|04 — Account frozen
      *>
      *>  Dependencies:
      *>    Requires ACCOUNTS.DAT in CWD. Read-only — does not
      *>    modify any files.
      *>
      *>  Change Log:
      *>    2026-02-17  AKD  Initial implementation — Phase 1
      *>    2026-02-23  AKD  Production headers, file status checks,
      *>                     copybook extraction
      *>
      *>================================================================*

      *>  This program demonstrates the validation pipeline pattern:
      *>  a series of sequential checks where each can reject early.
      *>  See the COBOL CONCEPT note at the validation sequence below.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. VALIDATE.

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
       01  WS-CMD-LINE            PIC X(200) VALUE SPACES.
       01  WS-IN-ACCT-ID          PIC X(10) VALUE SPACES.
       01  WS-IN-AMOUNT           PIC S9(10)V99 VALUE 0.
       01  WS-IN-AMOUNT-STR       PIC X(20) VALUE SPACES.
       01  WS-RESULT-CODE         PIC X(2) VALUE '00'.
       COPY "ACCTIO.cpy".
       01  WS-DAILY-LIMIT         PIC 9(10)V99 VALUE 50000.00.
       COPY "COMCODE.cpy".

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
      *>   Parse account ID and amount from command line
           ACCEPT WS-CMD-LINE FROM COMMAND-LINE
           UNSTRING WS-CMD-LINE DELIMITED BY SPACE
               INTO WS-IN-ACCT-ID
                    WS-IN-AMOUNT-STR
           END-UNSTRING
           MOVE FUNCTION TRIM(WS-IN-ACCT-ID) TO WS-IN-ACCT-ID
           MOVE FUNCTION TRIM(WS-IN-AMOUNT-STR) TO WS-IN-AMOUNT-STR

           IF WS-IN-AMOUNT-STR NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-IN-AMOUNT-STR)
                   TO WS-IN-AMOUNT
           END-IF

      *> ═══════════════════════════════════════════════════════════
      *> COBOL CONCEPT: Validation pipeline pattern
      *> This is the guard-clause or "chain of checks" pattern.
      *> Each validation step runs in sequence. If any check fails,
      *> it sets the result code and exits immediately (STOP RUN).
      *> Only if ALL checks pass does execution reach the final
      *> "RESULT|00" success output. The sequence matters:
      *>
      *>   1. Account exists?    (RESULT|03 if not)
      *>   2. Account active?    (RESULT|04 if frozen)
      *>   3. Sufficient funds?  (RESULT|01 if NSF)
      *>   4. Within limit?      (RESULT|02 if exceeded)
      *>   5. All clear          (RESULT|00)
      *>
      *> This is cleaner than nested IF/ELSE because each check
      *> is an independent paragraph. Adding a new rule means
      *> adding one PERFORM + one IF block — no restructuring.
      *> ═══════════════════════════════════════════════════════════

      *>   Step 1: Load accounts and find the target
           PERFORM LOAD-ALL-ACCOUNTS
           PERFORM FIND-ACCOUNT

      *>   Step 2: Account must exist
           IF WS-FOUND-FLAG = 'N'
               MOVE RC-INVALID-ACCT TO WS-RESULT-CODE
               DISPLAY "RESULT|" WS-RESULT-CODE
               STOP RUN
           END-IF

      *>   Step 3: Account must not be frozen
           PERFORM CHECK-ACCOUNT-STATUS
           IF WS-RESULT-CODE NOT = '00'
               DISPLAY "RESULT|" WS-RESULT-CODE
               STOP RUN
           END-IF

      *>   Step 4: Sufficient balance for the requested amount
           PERFORM CHECK-BALANCE
           IF WS-RESULT-CODE NOT = '00'
               DISPLAY "RESULT|" WS-RESULT-CODE
               STOP RUN
           END-IF

      *>   Step 5: Amount within daily withdrawal limit
           PERFORM CHECK-DAILY-LIMIT
           IF WS-RESULT-CODE NOT = '00'
               DISPLAY "RESULT|" WS-RESULT-CODE
               STOP RUN
           END-IF

      *>   All checks passed
           DISPLAY "RESULT|" WS-RESULT-CODE

           STOP RUN.

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
      *> CHECK-ACCOUNT-STATUS: Reject frozen accounts.
      *> Uses EXIT PARAGRAPH as an early return — if the account
      *> is frozen, set the code and skip the rest of the paragraph.
      *> -------------------------------------------------------
       CHECK-ACCOUNT-STATUS.
           MOVE '00' TO WS-RESULT-CODE
           IF WS-A-STATUS(WS-FOUND-IDX) = 'F'
               MOVE RC-ACCOUNT-FROZEN TO WS-RESULT-CODE
               EXIT PARAGRAPH
           END-IF.

      *> -------------------------------------------------------
      *> CHECK-BALANCE: Reject if account balance < requested amount.
      *> -------------------------------------------------------
       CHECK-BALANCE.
           MOVE '00' TO WS-RESULT-CODE
           IF WS-A-BALANCE(WS-FOUND-IDX) < WS-IN-AMOUNT
               MOVE RC-NSF TO WS-RESULT-CODE
               EXIT PARAGRAPH
           END-IF.

      *> -------------------------------------------------------
      *> CHECK-DAILY-LIMIT: Reject if amount exceeds $50,000 limit.
      *> In production, this would aggregate same-day transactions.
      *> -------------------------------------------------------
       CHECK-DAILY-LIMIT.
           MOVE '00' TO WS-RESULT-CODE
           IF WS-IN-AMOUNT > WS-DAILY-LIMIT
               MOVE RC-LIMIT-EXCEEDED TO WS-RESULT-CODE
               EXIT PARAGRAPH
           END-IF.
