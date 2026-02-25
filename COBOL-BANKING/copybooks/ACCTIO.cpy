*> ================================================================
*> ACCTIO.cpy — Shared Account I/O Working-Storage Variables
*> Used by: ACCOUNTS.cob, TRANSACT.cob, VALIDATE.cob,
*>          INTEREST.cob, FEES.cob, RECONCILE.cpy
*>
*> Provides the in-memory account table and search index variables
*> used by LOAD-ALL-ACCOUNTS, FIND-ACCOUNT, and WRITE-ALL-ACCOUNTS
*> paragraphs across all programs that operate on ACCOUNTS.DAT.
*>
*> Usage: COPY "ACCTIO.cpy" in WORKING-STORAGE SECTION.
*>
*> Note: PROCEDURE DIVISION paragraphs (LOAD-ALL-ACCOUNTS,
*> FIND-ACCOUNT, WRITE-ALL-ACCOUNTS) follow a shared pattern
*> but remain in each program to allow per-program customization
*> (e.g., TRANSACT names its write paragraph SAVE-ALL-ACCOUNTS).
*> This is standard enterprise COBOL practice — shared data layout,
*> per-program procedure logic.
*> ================================================================
*>
*> ═══════════════════════════════════════════════════════════
*> COBOL CONCEPT: OCCURS Clause (Arrays in COBOL)
*> COBOL does not have dynamic arrays or lists. Instead, you
*> declare a fixed-size table using OCCURS N TIMES. Here,
*> WS-ACCT-ENTRY OCCURS 100 TIMES creates space for up to
*> 100 account records in memory. Each entry is accessed by
*> subscript: WS-A-ID(1), WS-A-ID(2), ..., WS-A-ID(100).
*> The subscript must be a numeric variable or literal, and
*> COBOL subscripts start at 1 (not 0 like C or Python).
*>
*> The shared table pattern: This copybook defines the table
*> structure once, and every program that needs to work with
*> accounts in memory COPYs it. WS-ACCOUNT-COUNT tracks how
*> many entries are actually filled (like a "length" variable),
*> and WS-ACCT-IDX is a reusable loop counter for PERFORM
*> VARYING loops over the table.
*> ═══════════════════════════════════════════════════════════
*>
*> Search result flags — set by the FIND-ACCOUNT paragraph
 01  WS-FOUND-FLAG          PIC X VALUE 'N'.
 01  WS-FOUND-IDX           PIC 9(3) VALUE 0.
*> How many accounts are currently loaded (0 to 100)
 01  WS-ACCOUNT-COUNT       PIC 9(3) VALUE 0.
*> Loop index for PERFORM VARYING over the table
 01  WS-ACCT-IDX            PIC 9(3) VALUE 0.
*> The account table itself — up to 100 entries, each mirroring
*> the 70-byte ACCOUNT-RECORD layout from ACCTREC.cpy.
*> Accessed by subscript: WS-A-BALANCE(3) = balance of 3rd account.
 01  WS-ACCOUNT-TABLE.
     05  WS-ACCT-ENTRY OCCURS 100 TIMES.
         10  WS-A-ID        PIC X(10).
         10  WS-A-NAME      PIC X(30).
         10  WS-A-TYPE      PIC X(1).
         10  WS-A-BALANCE   PIC S9(10)V99.
         10  WS-A-STATUS    PIC X(1).
         10  WS-A-OPEN      PIC 9(8).
         10  WS-A-ACTIVITY  PIC 9(8).
