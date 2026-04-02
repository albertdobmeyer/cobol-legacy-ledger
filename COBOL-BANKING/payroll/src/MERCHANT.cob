      *>================================================================*
      *>  EDUCATIONAL NOTE: This program contains INTENTIONAL anti-patterns
      *>  for teaching purposes. See KNOWN_ISSUES.md for the full catalog.
      *>  All other COBOL in this project follows clean, modern practices.
      *>================================================================*
      *>  Program:     MERCHANT.cob
      *>  System:      PAYMENT PROCESSOR — Merchant Onboarding & Risk Tiering
      *>  Author:      TKN (Thomas K. Nguyen), original 1978
      *>  Written:     1978-08-14 (IBM System/370 Model 148)
      *>
      *>  JCL Reference:
      *>    //MERCH100 JOB (ACCT),'MERCHANT ONBOARD',CLASS=A
      *>    //STEP01   EXEC PGM=MERCHANT,REGION=256K
      *>    //MERCHFL  DD DSN=MERCH.MASTER.FILE,DISP=SHR
      *>    //SYSOUT   DD SYSOUT=*
      *>
      *>  Change Log:
      *>    1978-08-14  TKN  Initial — ONBOARD and LOOKUP operations
      *>    1978-11-02  TKN  Added MCC risk tiering via GO TO DEPENDING
      *>    1979-03-18  TKN  Bug fix — MCC-TBL-X off-by-one in RETIER
      *>    1979-09-07  TKN  Added LIST operation, "temporary" WK-M4
      *>    1980-06-11  TKN  Reserve % moved to shared WS (coupling)
      *>    1981-01-22  TKN  COPY REPLACING for COMCODE namespace
      *>    1981-04-30  TKN  Dead paragraph MR-055 — abandoned VIP
      *>
      *>  WARNING: GO TO DEPENDING ON routes MCC codes at runtime.
      *>  Update BOTH MR-030 AND MR-040 or you get garbage.
      *>  Shared WK-M1..WK-M7 couple all paragraphs.
      *>
      *>  EXEC CICS MIGRATION: This program was originally a CICS
      *>  online transaction (TRANID MRCH). EXEC CICS statements are
      *>  the primary migration blocker — they require replacing the
      *>  entire CICS middleware with SCREEN SECTION I/O and native
      *>  file operations. EBCDIC→ASCII conversion during migration
      *>  corrupts signed DISPLAY fields (overpunch encoding differs),
      *>  hex literals in VALUE clauses change meaning (X'C1' = 'A'
      *>  in EBCDIC but a different character in ASCII), and INSPECT
      *>  CONVERTING with literal character strings produces wrong
      *>  results. TSB Bank's 2018 migration from Lloyds' mainframe
      *>  to a new platform left 1.9 million customers locked out —
      *>  a cautionary tale for COBOL migration projects.
      *>
      *>  3270 TERMINAL HERITAGE: The ACCEPT statement on line MR-000
      *>  retrieves data that on a mainframe would come from a 3270
      *>  terminal screen (80x24 characters). The PIC X(120) for
      *>  WS-CMD-LINE mirrors the BMS map field length from the
      *>  original CICS transaction's BMS mapset.
      *>
      *>  CICS vs BATCH WS PERSISTENCE: In batch COBOL, WORKING-
      *>  STORAGE persists throughout program execution. In CICS,
      *>  each task gets a fresh copy (compiled RENT). WK-M1..WK-M7
      *>  would reset between pseudo-conversational transactions
      *>  unless state is passed through COMMAREA (max 32,763 bytes)
      *>  or Channels and Containers (CICS TS 3.1+).
      *>
      *>  Paragraph Flow (GO TO DEPENDING ON can change this):
      *>    MR-000 → MR-010 → MR-020 → MR-030 → MR-040 →
      *>    [MR-041..044] → MR-050 → MR-060 → MR-070 → MR-090
      *>================================================================*

       IDENTIFICATION DIVISION.
       PROGRAM-ID. MERCHANT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MERCHANT-FILE
               ASSIGN TO "MERCHANTS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-MF-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MERCHANT-FILE.
           COPY "MERCHREC.cpy".

       WORKING-STORAGE SECTION.
       01  WS-MF-STATUS              PIC X(2).
       01  WS-FLAGS.
           05  WS-EOF-FLAG            PIC X(1) VALUE 'N'.
               88  WS-EOF             VALUE 'Y'.
               88  WS-NOT-EOF         VALUE 'N'.
           05  WS-FOUND-FLAG          PIC X(1) VALUE 'N'.
               88  WS-FOUND           VALUE 'Y'.
               88  WS-NOT-FOUND       VALUE 'N'.
           05  WS-OP-CODE             PIC 9(1) VALUE 0.
      *> TKN: Cryptic work fields — shared WORKING-STORAGE parameters.
      *> Paragraphs communicate through globals instead of USING.
      *>
      *>   FIELD REUSE AMBIGUITY: WK-M4 has THREE different meanings
      *>   depending on which paragraph you're reading:
      *>     (a) In MR-030: "known MCC" flag (0 or 1)
      *>     (b) In MR-040/041-044: risk score accumulator
      *>     (c) In MR-072 (RETIER): fee tier index
      *>   Modifying WK-M4 in one context silently corrupts the other
      *>   two. The paths are "safe" only because MR-030 runs before
      *>   MR-040, and MR-072 is a separate operation — but if the
      *>   dispatch order ever changes, all three meanings collide.
      *>
      *>   GROUP MOVE HAZARD: Moving WS-WORK-FIELDS as a group to
      *>   another group treats ALL subordinate items as alphanumeric
      *>   regardless of their PIC types. WK-M3 (PIC 9(4)) and WK-M6
      *>   (PIC 9V9999) lose decimal alignment in a group MOVE. The
      *>   receiving fields get raw character bytes, not numeric values.
       01  WS-WORK-FIELDS.
           05  WK-M1                  PIC X(10).
           05  WK-M2                  PIC X(30).
           05  WK-M3                  PIC 9(4).
           05  WK-M4                  PIC 9(1).
           05  WK-M5                  PIC X(8).
           05  WK-M6                  PIC 9V9999.
           05  WK-M7                  PIC X(1).
       01  WS-MCC-FIELDS.
           05  MCC-TBL-X              PIC 9(1) VALUE 0.
           05  MCC-TBL-RISK           PIC 9(1) VALUE 0.
           05  MCC-TBL-RSV            PIC 9V9999 VALUE 0.
      *> Hardcoded MCC ranges — magic numbers from "page 47"
       01  WS-MCC-MAGIC.
           05  WK-MCC-RETAIL-LO       PIC 9(4) VALUE 5200.
           05  WK-MCC-RETAIL-HI       PIC 9(4) VALUE 5499.
           05  WK-MCC-FOOD-LO         PIC 9(4) VALUE 5800.
           05  WK-MCC-FOOD-HI         PIC 9(4) VALUE 5899.
           05  WK-MCC-GAMBLE-LO       PIC 9(4) VALUE 7990.
           05  WK-MCC-GAMBLE-HI       PIC 9(4) VALUE 7999.
       01  WS-COUNTERS.
           05  WS-READ-COUNT          PIC 9(5) VALUE 0.
           05  WS-ONBOARD-COUNT       PIC 9(5) VALUE 0.
           05  WS-RETIER-COUNT        PIC 9(5) VALUE 0.
       01  WS-CMD-ARGS.
           05  WS-CMD-LINE            PIC X(120) VALUE SPACES.
           05  WS-CMD-OP              PIC X(8) VALUE SPACES.
           05  WS-CMD-ID              PIC X(10) VALUE SPACES.
           05  WS-CMD-NAME            PIC X(30) VALUE SPACES.
           05  WS-CMD-MCC             PIC 9(4) VALUE 0.
           05  WS-CMD-BANK            PIC X(8) VALUE SPACES.
           05  WS-CMD-TYPE            PIC X(1) VALUE 'I'.
       01  WS-CURRENT-DATE.
           05  WS-DATE-YYYY           PIC 9(4).
           05  WS-DATE-MM             PIC 9(2).
           05  WS-DATE-DD             PIC 9(2).

      *> TKN 1981: COPY REPLACING — "namespace safety" for COMCODE.
      *> Renames 01-level group. Just makes constants harder to grep.
           COPY "COMCODE.cpy"
               REPLACING ==RESULT-CODES== BY ==MR-RESULT-CODES==.
      *> Temp record for RETIER file rebuild
       01  WS-TEMP-RECORD             PIC X(120).
       01  WS-LIST-COUNT              PIC 9(3) VALUE 0.

      *> ── DEAD FIELDS (unreferenced by executable code) ────────
      *> CICS heritage: EIBTRMID = terminal ID from EXEC CICS
      *> ASSIGN EIBTRMID. On a mainframe, this identifies which
      *> 3270 terminal submitted the transaction.
       01  WS-DEAD-CICS-EIBTRMID     PIC X(4) VALUE SPACES.
      *> DB2 heritage: DCLGEN generates COBOL copybooks from DB2
      *> table definitions. This timestamp would be populated by
      *> EXEC SQL SELECT CURRENT TIMESTAMP. Indicator variables
      *> (PIC S9(4) COMP) signal NULLs when set to -1.
       01  WS-DEAD-DCLGEN-TIMESTAMP  PIC X(26) VALUE SPACES.
      *> BMS screen map name — identifies the CICS Basic Mapping
      *> Support mapset. PIC X(7) mirrors the BMS map field length.
       01  WS-DEAD-BMS-MAP-NAME      PIC X(7) VALUE SPACES.
      *> Audit trail for tier changes — previous tier before retier
       01  WS-DEAD-PREV-TIER         PIC 9(1) VALUE 0.
      *> Tier upgrade flag — contradicts MERCH-HIGH-RISK (tier 4-5).
      *> This 88 says tiers 1-3 are "upgraded" but MERCH-HIGH-RISK
      *> says 4-5 are "high risk." Upgrading TO high risk is unclear.
       01  WS-DEAD-TIER-UPGRADED     PIC X(1) VALUE 'N'.
           88  WS-DEAD-IS-UPGRADE    VALUE 'Y'.

       PROCEDURE DIVISION.

      *>================================================================*
      *>  MR-000: MAINLINE — Parse command and dispatch
      *>================================================================*
       MR-000.
           ACCEPT WS-CMD-LINE FROM COMMAND-LINE.
           MOVE WS-CMD-LINE(1:8) TO WS-CMD-OP.

      *>   Numeric dispatch — "faster than string compare" (1978)
           IF WS-CMD-OP = 'ONBOARD '
               MOVE 1 TO WS-OP-CODE
           ELSE IF WS-CMD-OP = 'LOOKUP  '
               MOVE 2 TO WS-OP-CODE
           ELSE IF WS-CMD-OP = 'RETIER  '
               MOVE 3 TO WS-OP-CODE
           ELSE IF WS-CMD-OP = 'LIST    '
               MOVE 4 TO WS-OP-CODE
           ELSE
               DISPLAY "MERCHANT|ERROR|UNKNOWN-OP|" WS-CMD-OP
               DISPLAY "RESULT|03"
               GO TO MR-090.

           IF WS-OP-CODE = 1
               MOVE WS-CMD-LINE(10:10) TO WS-CMD-ID
               MOVE WS-CMD-LINE(21:30) TO WS-CMD-NAME
               MOVE WS-CMD-LINE(52:4)  TO WS-CMD-MCC
               MOVE WS-CMD-LINE(57:8)  TO WS-CMD-BANK
               MOVE WS-CMD-LINE(66:1)  TO WS-CMD-TYPE.
           IF WS-OP-CODE = 2 OR WS-OP-CODE = 3
               MOVE WS-CMD-LINE(10:10) TO WS-CMD-ID.

           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.

      *>   Set up shared work fields — THIS IS THE COUPLING
           MOVE WS-CMD-ID   TO WK-M1.
           MOVE WS-CMD-NAME TO WK-M2.
           MOVE WS-CMD-MCC  TO WK-M3.
           MOVE 0           TO WK-M4.
           MOVE WS-CMD-BANK TO WK-M5.
           MOVE 0           TO WK-M6.
           MOVE WS-CMD-TYPE TO WK-M7.

      *>   GO TO DEPENDING ON — the COBOL-68 CASE statement
           GO TO MR-010 MR-060 MR-070 MR-080
               DEPENDING ON WS-OP-CODE.
           DISPLAY "RESULT|99"
           GO TO MR-090.

      *>  MR-010: ONBOARD — Check duplicate then build record
       MR-010.
           DISPLAY "MERCHANT|ONBOARD|START|" WK-M1.
           OPEN INPUT MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               IF WS-MF-STATUS = '35'
                   GO TO MR-020
               END-IF
               DISPLAY "MERCHANT|ERROR|FILE|" WS-MF-STATUS
               DISPLAY "RESULT|99"
               GO TO MR-090.

           SET WS-NOT-FOUND TO TRUE.
           PERFORM MR-015 UNTIL WS-EOF OR WS-FOUND.
           CLOSE MERCHANT-FILE.
           IF WS-FOUND
               DISPLAY "MERCHANT|ERROR|DUPLICATE|" WK-M1
               DISPLAY "RESULT|03"
               GO TO MR-090.
           GO TO MR-020.
      *>  MR-015: Duplicate scan — period-terminated
       MR-015.
           READ MERCHANT-FILE
               AT END
                   SET WS-EOF TO TRUE.
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
               IF MERCH-ID = WK-M1
                   SET WS-FOUND TO TRUE.
      *>  MR-020: BUILD RECORD from shared WK-M fields (coupling)
       MR-020.
           MOVE WK-M1 TO MERCH-ID.
           MOVE WK-M2 TO MERCH-LEGAL-NAME.
           MOVE WK-M3 TO MERCH-MCC-CODE.
           MOVE WK-M5 TO MERCH-SPONSOR-BANK.
           MOVE WS-CURRENT-DATE TO MERCH-ONBOARD-DATE.
           SET  MERCH-PENDING TO TRUE.
           MOVE WK-M7 TO MERCH-TYPE.
      *>   No END-IF — period-terminated type dispatch
           IF MERCH-TYPE-INDIV
               MOVE WK-M2(1:8) TO MERCH-DBA-NAME.
           IF MERCH-TYPE-AGGR
               MOVE "CHAIN" TO MERCH-CHAIN-ID
               MOVE 1 TO MERCH-UNIT-COUNT.
      *>   Magic numbers: 50000 individual, 500000 aggregate
           IF MERCH-TYPE-INDIV
               MOVE 50000.00 TO MERCH-VOLUME-LIMIT
           ELSE
               MOVE 500000.00 TO MERCH-VOLUME-LIMIT.
           MOVE 1 TO MERCH-FEE-TIER.
           MOVE 0 TO MERCH-MONTHLY-VOL.
           MOVE SPACES TO MERCH-FILLER.
           GO TO MR-030.

      *>  MR-030: MCC CATEGORY — period-terminated nested IF
       MR-030.
      *>   No END-IF — period terminates ALL nested IFs
           IF WK-M3 >= WK-MCC-RETAIL-LO AND
              WK-M3 <= WK-MCC-RETAIL-HI
               MOVE 1 TO MCC-TBL-X
               MOVE 1 TO WK-M4
           ELSE
           IF WK-M3 >= WK-MCC-FOOD-LO AND
              WK-M3 <= WK-MCC-FOOD-HI
               MOVE 2 TO MCC-TBL-X
               MOVE 1 TO WK-M4
           ELSE
           IF WK-M3 >= WK-MCC-GAMBLE-LO AND
              WK-M3 <= WK-MCC-GAMBLE-HI
               MOVE 3 TO MCC-TBL-X
               MOVE 1 TO WK-M4
           ELSE
               MOVE 4 TO MCC-TBL-X
               MOVE 0 TO WK-M4.
      *>  MR-040: GO TO DEPENDING ON — computed branch
       MR-040.
           GO TO MR-041 MR-042 MR-043 MR-044
               DEPENDING ON MCC-TBL-X.
           MOVE 3 TO MCC-TBL-RISK
           MOVE 0.0500 TO MCC-TBL-RSV
           GO TO MR-050.

       MR-041.
           MOVE 1 TO MCC-TBL-RISK.
           MOVE 0.0200 TO MCC-TBL-RSV.
           GO TO MR-050.
       MR-042.
           MOVE 2 TO MCC-TBL-RISK.
           MOVE 0.0350 TO MCC-TBL-RSV.
           GO TO MR-050.
       MR-043.
           MOVE 5 TO MCC-TBL-RISK.
           MOVE 0.1000 TO MCC-TBL-RSV.
           GO TO MR-050.
       MR-044.
           MOVE 3 TO MCC-TBL-RISK.
           MOVE 0.0500 TO MCC-TBL-RSV.
           GO TO MR-050.

      *>================================================================*
      *>  MR-050: APPLY RISK — Write record
      *>  KNOWN ISSUE: WK-M4 is "known MCC" flag, not "override".
      *>  Bumps risk for known MCCs (backwards from intent):
      *>    Retail: 1+1=2  Food: 2+1=3  Gambling: capped 5  Other: 3+0=3
      *>================================================================*
       MR-050.
      *>   TKN: "If override flag is set, bump risk" — WRONG COMMENT
           IF WK-M4 = 1
               ADD 1 TO MCC-TBL-RISK
               IF MCC-TBL-RISK > 5
                   MOVE 5 TO MCC-TBL-RISK.
           MOVE MCC-TBL-RISK TO MERCH-RISK-TIER.
           MOVE MCC-TBL-RSV  TO MERCH-RESERVE-PCT.

           OPEN EXTEND MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               OPEN OUTPUT MERCHANT-FILE
               IF WS-MF-STATUS NOT = '00'
                   DISPLAY "MERCHANT|ERROR|WRITE|" WS-MF-STATUS
                   DISPLAY "RESULT|99"
                   GO TO MR-090.
           WRITE MERCHANT-RECORD.
           ADD 1 TO WS-ONBOARD-COUNT.
           CLOSE MERCHANT-FILE.
           DISPLAY "OK|ONBOARD|" MERCH-ID "|" MERCH-RISK-TIER "|"
               MERCH-STATUS.
           DISPLAY "RESULT|" RC-SUCCESS.
           GO TO MR-090.

      *>  MR-055: DEAD — VIP override (1981). Compliance said no.
       MR-055.
           MOVE 1 TO MCC-TBL-RISK.
           MOVE 0.0100 TO MCC-TBL-RSV.
           GO TO MR-050.

      *>================================================================*
      *>  MR-060: LOOKUP — Sequential scan, display details
      *>
      *>  EBCDIC SORT ORDER: The IF comparison on MERCH-ID uses
      *>  character equality. On EBCDIC: 'a' < 'A' < '1'. On ASCII:
      *>  '1' < 'A' < 'a'. If SEARCH ALL (binary search) were used
      *>  on a table sorted in EBCDIC order, it would produce wrong
      *>  results on ASCII platforms. PROGRAM COLLATING SEQUENCE IS
      *>  can override this, but every missed instance is a subtle
      *>  migration bug. This sequential scan is safe (equality only),
      *>  but MR-072's inline MCC comparison IS order-dependent.
      *>
      *>  REDEFINES GUARD: When displaying merchant details, this
      *>  paragraph reads MERCH-DBA-NAME (individual) or MERCH-CHAIN-
      *>  ID (aggregate) depending on MERCH-TYPE. But MR-072 (RETIER)
      *>  accesses the REDEFINES without checking MERCH-TYPE first —
      *>  a missing 88-level type guard in at least one code path.
      *>
      *>  FILE STATUS: This paragraph checks WS-MF-STATUS after OPEN
      *>  but not after each READ. Codes to memorize: 00=success,
      *>  10=EOF, 22=duplicate key, 23=record not found, 35=file
      *>  not found. Unchecked FILE STATUS means a corrupted record
      *>  returns stale data from the previous successful READ.
      *>================================================================*
       MR-060.
           OPEN INPUT MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               DISPLAY "RESULT|99"
               GO TO MR-090.
           SET WS-NOT-FOUND TO TRUE.
           SET WS-NOT-EOF TO TRUE.
       MR-061.
           READ MERCHANT-FILE
               AT END
                   SET WS-EOF TO TRUE
                   GO TO MR-062.
           IF MERCH-ID = WK-M1
               SET WS-FOUND TO TRUE
               GO TO MR-062.
           GO TO MR-061.

       MR-062.
           CLOSE MERCHANT-FILE.
           IF WS-NOT-FOUND
               DISPLAY "MERCHANT|LOOKUP|NOT-FOUND|" WK-M1
               DISPLAY "RESULT|" RC-INVALID-ACCT
               GO TO MR-090.
           DISPLAY "OK|LOOKUP|" MERCH-ID "|" MERCH-RISK-TIER "|"
               MERCH-STATUS.
           DISPLAY "MERCHANT|DETAIL|NAME=" MERCH-LEGAL-NAME.
           DISPLAY "MERCHANT|DETAIL|MCC=" MERCH-MCC-CODE.
           DISPLAY "MERCHANT|DETAIL|RISK=" MERCH-RISK-TIER.
           DISPLAY "MERCHANT|DETAIL|BANK=" MERCH-SPONSOR-BANK.
           DISPLAY "MERCHANT|DETAIL|TYPE=" MERCH-TYPE.
           IF MERCH-TYPE-INDIV
               DISPLAY "MERCHANT|DETAIL|DBA=" MERCH-DBA-NAME.
           IF MERCH-TYPE-AGGR
               DISPLAY "MERCHANT|DETAIL|CHAIN=" MERCH-CHAIN-ID.
           DISPLAY "RESULT|" RC-SUCCESS.
           GO TO MR-090.

      *>================================================================*
      *>  MR-070: RETIER — Find, recompute risk, rebuild file
      *>  Copy-paste of MR-030 — "I'll refactor later" (1979, never)
      *>================================================================*
       MR-070.
           OPEN INPUT MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               DISPLAY "RESULT|99"
               GO TO MR-090.
           SET WS-NOT-FOUND TO TRUE.
           SET WS-NOT-EOF TO TRUE.

       MR-071.
           READ MERCHANT-FILE
               AT END
                   SET WS-EOF TO TRUE
                   GO TO MR-072.
           IF MERCH-ID = WK-M1
               SET WS-FOUND TO TRUE
               MOVE MERCH-MCC-CODE TO WK-M3
               MOVE MERCHANT-RECORD TO WS-TEMP-RECORD
               GO TO MR-072.
           GO TO MR-071.

       MR-072.
           CLOSE MERCHANT-FILE.
           IF WS-NOT-FOUND
               DISPLAY "MERCHANT|RETIER|NOT-FOUND|" WK-M1
               DISPLAY "RESULT|" RC-INVALID-ACCT
               GO TO MR-090.

      *>   Inline MCC logic — copy-paste from MR-030.
      *>   TKN forgot to use WK-MCC-* constants here. If someone
      *>   changes the ranges in WS-MCC-MAGIC, RETIER diverges.
           IF WK-M3 >= 5200 AND WK-M3 <= 5499
               MOVE 1 TO MCC-TBL-RISK
               MOVE 0.0200 TO MCC-TBL-RSV
           ELSE
           IF WK-M3 >= 5800 AND WK-M3 <= 5899
               MOVE 2 TO MCC-TBL-RISK
               MOVE 0.0350 TO MCC-TBL-RSV
           ELSE
           IF WK-M3 >= 7990 AND WK-M3 <= 7999
               MOVE 5 TO MCC-TBL-RISK
               MOVE 0.1000 TO MCC-TBL-RSV
           ELSE
               MOVE 3 TO MCC-TBL-RISK
               MOVE 0.0500 TO MCC-TBL-RSV.

      *>   Rebuild file with updated record
           MOVE WS-TEMP-RECORD TO MERCHANT-RECORD.
           MOVE MCC-TBL-RISK TO MERCH-RISK-TIER.
           MOVE MCC-TBL-RSV  TO MERCH-RESERVE-PCT.

           OPEN OUTPUT MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               DISPLAY "RESULT|99"
               GO TO MR-090.
           WRITE MERCHANT-RECORD.
           ADD 1 TO WS-RETIER-COUNT.
           CLOSE MERCHANT-FILE.
           DISPLAY "OK|RETIER|" MERCH-ID "|" MERCH-RISK-TIER "|"
               MERCH-STATUS.
           DISPLAY "RESULT|" RC-SUCCESS.
           GO TO MR-090.

      *>================================================================*
      *>  MR-080: LIST — Sequential read, display all merchants
      *>================================================================*
       MR-080.
           DISPLAY "MERCHANT|LIST|START".
           OPEN INPUT MERCHANT-FILE.
           IF WS-MF-STATUS NOT = '00'
               IF WS-MF-STATUS = '35'
                   DISPLAY "MERCHANT|LIST|EMPTY"
                   DISPLAY "RESULT|" RC-SUCCESS
                   GO TO MR-090.
               DISPLAY "RESULT|99"
               GO TO MR-090.
           SET WS-NOT-EOF TO TRUE.
           MOVE 0 TO WS-LIST-COUNT.

       MR-081.
           READ MERCHANT-FILE
               AT END
                   SET WS-EOF TO TRUE
                   GO TO MR-082.
           ADD 1 TO WS-LIST-COUNT.
           DISPLAY "MERCHANT|ENTRY|"
               MERCH-ID "|" MERCH-LEGAL-NAME "|"
               MERCH-MCC-CODE "|" MERCH-RISK-TIER "|"
               MERCH-STATUS "|" MERCH-SPONSOR-BANK "|"
               MERCH-TYPE.
           IF MERCH-TYPE-AGGR
               DISPLAY "MERCHANT|CHAIN|"
                   MERCH-ID "|" MERCH-CHAIN-ID "|"
                   MERCH-UNIT-COUNT.
           GO TO MR-081.

       MR-082.
           CLOSE MERCHANT-FILE.
           DISPLAY "MERCHANT|LIST|COUNT=" WS-LIST-COUNT.
           DISPLAY "RESULT|" RC-SUCCESS.
           GO TO MR-090.

      *>  MR-085: DEAD — Fee auto-promotion (1979). Compliance blocked.
       MR-085.
           IF MERCH-TIER-STARTUP
               IF MERCH-MONTHLY-VOL > 10000
                   MOVE 2 TO MERCH-FEE-TIER
                   DISPLAY "MERCHANT|AUTO-PROMO|" MERCH-ID.

      *>================================================================*
      *>  MR-090: EXIT POINT
      *>================================================================*
       MR-090.
           STOP RUN.
