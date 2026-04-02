       *>================================================================*
       *>  EDUCATIONAL NOTE: This program contains INTENTIONAL anti-patterns
       *>  for teaching purposes. See KNOWN_ISSUES.md for the full catalog.
       *>  All other COBOL in this project follows clean, modern practices.
       *>================================================================*
       *>  Program:     FEEENGN.cob
       *>  System:      MERCHANT FEE CALCULATION ENGINE
       *>  Author:      RBJ (Robert "Bobby" Johnson, 1986)
       *>  Written:     1986-08-12 (IBM 4381 Model Group 14)
       *>
       *>  JCL: //FEEENG00 JOB (ACCT),'MERCHANT FEES',CLASS=B
       *>       //STEP01 EXEC PGM=FEEENGN //MERCHFL DD DISP=SHR
       *>       //TXNFILE DD DISP=SHR //SORTWK01 DD SPACE=(CYL,5)
       *>
       *>  Change Log:
       *>    1986-08-12  RBJ  Initial — interchange+ fee calculator
       *>    1986-11-05  RBJ  Added SORT for tiered batch processing
       *>    1987-03-18  RBJ  Fixed cross-border uplift (was doubling)
       *>    1989-01-15  RBJ  "Temporary" blended pricing — 2.9%+$0.30
       *>    1989-06-30  RBJ  Q2 passed. Leaving blend for Q3.
       *>    1992-04-10  RBJ  Updated Amex rate. Blend still "temporary."
       *>    1994-07-22  ACS  Added tier 4 stub. Did not implement.
       *>
       *>  SORT VERB CONCEPT: COBOL SORT takes control of execution.
       *>    INPUT PROCEDURE: you RELEASE records. SORT sorts them.
       *>    OUTPUT PROCEDURE: you RETURN in order. Coroutine-style.
       *>
       *>  ANTI-PATTERNS:
       *>    1. SORT INPUT/OUTPUT PROCEDURE (callback-style flow)
       *>    2. Triple-nested PERFORM VARYING (O(4*4*3))
       *>    3. Hardcoded rates contradicting the copybook
       *>    4. "Temporary" blended pricing — active since 1989
       *>    5. Magic numbers everywhere  6. Misleading comments
       *>================================================================*

       IDENTIFICATION DIVISION.
       PROGRAM-ID. FEEENGN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MERCHANT-FILE ASSIGN TO "MERCHANTS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-MERCH-STATUS.
           SELECT TRANSACTION-FILE ASSIGN TO "TRANSACT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-TX-STATUS.
           SELECT SORT-WORK ASSIGN TO "SORTWORK.TMP".

       DATA DIVISION.
       FILE SECTION.
       FD  MERCHANT-FILE.
           COPY "MERCHREC.cpy".
       FD  TRANSACTION-FILE.
       01  TX-INPUT-RECORD.
           05  TX-IN-ID              PIC X(12).
           05  TX-IN-MERCH-ID        PIC X(10).
           05  TX-IN-TYPE            PIC X(1).
           05  TX-IN-AMOUNT          PIC S9(10)V99.
           05  TX-IN-DATE            PIC 9(8).
           05  TX-IN-TIME            PIC 9(6).
           05  TX-IN-DESC            PIC X(40).
           05  TX-IN-STATUS          PIC X(2).
           05  TX-IN-BATCH-ID        PIC X(12).
       SD  SORT-WORK.
       01  SORT-RECORD.
           05  SORT-FEE-TIER         PIC 9(1).
           05  SORT-MERCH-ID         PIC X(10).
           05  SORT-TX-AMOUNT        PIC S9(10)V99.
           05  SORT-MCC-CODE         PIC 9(4).
           05  SORT-NETWORK-IDX      PIC 9(1).

       WORKING-STORAGE SECTION.
       01  WS-MERCH-STATUS           PIC X(2).
       01  WS-TX-STATUS              PIC X(2).
       01  WS-MERCH-EOF              PIC X(1) VALUE 'N'.
           88  WS-MERCH-DONE         VALUE 'Y'.
       01  WS-TX-EOF                 PIC X(1) VALUE 'N'.
           88  WS-TX-DONE            VALUE 'Y'.
       01  WS-SORT-EOF               PIC X(1) VALUE 'N'.
           88  WS-SORT-DONE          VALUE 'Y'.
       01  WS-OPERATION              PIC X(6) VALUE SPACES.
      *> Hardcoded rates — CONFLICT with FEEREC copybook (neither updated)
       01  WS-VISA-RATE              PIC S9V9999 COMP-3 VALUE 0.0175.
       01  WS-MC-RATE                PIC S9V9999 COMP-3 VALUE 0.0185.
       01  WS-AMEX-RATE              PIC S9V9999 COMP-3 VALUE 0.0275.
       01  WS-DISC-RATE              PIC S9V9999 COMP-3 VALUE 0.0215.
       01  WS-PER-TX-VISA            PIC S9(3) COMP VALUE 10.
       01  WS-PER-TX-MC              PIC S9(3) COMP VALUE 10.
       01  WS-PER-TX-AMEX            PIC S9(3) COMP VALUE 15.
       01  WS-PER-TX-DISC            PIC S9(3) COMP VALUE 8.
       01  WS-BPS-1                  PIC S9(4) COMP VALUE 50.
       01  WS-BPS-2                  PIC S9(4) COMP VALUE 35.
       01  WS-BPS-3                  PIC S9(4) COMP VALUE 20.
       01  WS-MCC-RANGES.
           05  WS-MCC-RANGE OCCURS 3 TIMES.
               10  WS-MCC-LO         PIC 9(4).
               10  WS-MCC-HI         PIC 9(4).
               10  WS-MCC-PREMIUM    PIC X(1).
       01  WS-NET-IDX                PIC 9(2).
       01  WS-TIER-IDX               PIC 9(2).
       01  WS-MCC-IDX                PIC 9(2).
       01  WS-MERCH-TX-COUNT         PIC S9(7) COMP VALUE 0.
       01  WS-MERCH-TX-TOTAL         PIC S9(10)V99 COMP-3 VALUE 0.
       01  WS-BATCH-FEE-TOTAL        PIC S9(10)V99 COMP-3 VALUE 0.
       01  WS-BATCH-MERCH-COUNT      PIC S9(5) COMP VALUE 0.
       01  WS-BATCH-TX-COUNT         PIC S9(7) COMP VALUE 0.
       01  WS-SORT-TX-COUNT          PIC S9(7) COMP VALUE 0.
       01  WS-RATE-WORK              PIC S9V9999 COMP-3.
       01  WS-TX-FEE                 PIC S9(7)V99 COMP-3.
       01  WS-NET-MATCHED            PIC X(1) VALUE 'N'.
       01  WS-TIER-MATCHED           PIC X(1) VALUE 'N'.
       01  WS-IS-PREMIUM             PIC X(1) VALUE 'N'.
       01  WS-CUR-MERCH-ID           PIC X(10).
       01  WS-CUR-FEE-TIER           PIC 9(1).
       01  WS-CUR-MCC                PIC 9(4).
       01  WS-CUR-MONTHLY-VOL        PIC S9(5)V99.
       01  WS-RESULT-CODE            PIC X(2) VALUE '00'.
       01  WS-FMT-IC                 PIC Z(6)9.99.
       01  WS-FMT-MK                 PIC Z(6)9.99.
       01  WS-FMT-TOT                PIC Z(6)9.99.
       01  WS-FMT-BTOT               PIC Z(9)9.99.
       01  WS-FMT-CNT                PIC Z(6)9.
       01  WS-HOLD-MERCH-ID          PIC X(10) VALUE SPACES.

           COPY "FEEREC.cpy".
           COPY "PAYCOM.cpy".

      *> ── DEAD FIELDS (unreferenced by executable code) ────────────
      *> Multi-currency heritage: real banking pairs every amount with
      *> its ISO 4217 currency code and a decimal-places indicator.
      *> JPY (yen) uses 0 decimal places; BHD (Bahraini dinar) uses 3.
      *> Our system is USD-only, but these fields document the pattern.
       01  WS-DEAD-CURRENCY-CODE     PIC X(3) VALUE 'USD'.
       01  WS-DEAD-DECIMAL-PLACES    PIC 9(1) VALUE 2.
      *> FX conversion rate — offshore team 2008 "for phase 2"
       01  WS-DEAD-FX-RATE           PIC S9(3)V9(6) COMP-3 VALUE 0.
      *> SORT return code — SORT sets SORT-RETURN but nobody checks it
       01  WS-DEAD-SORT-RC           PIC S9(4) COMP VALUE 0.
      *> Refund fee percentage — RBJ 1988, killed by legal review
       01  WS-DEAD-REFUND-PCT        PIC 9V9999 VALUE 0.
      *> Fee exemption flag — contradicts the fact that ALL merchants
      *> are charged; no code path ever sets this to 'Y'
       01  WS-DEAD-FEE-EXEMPT-FLAG   PIC X(1) VALUE 'N'.
           88  WS-DEAD-FEE-EXEMPT    VALUE 'Y'.

       PROCEDURE DIVISION.

       FE-MAIN.
           ACCEPT WS-OPERATION FROM COMMAND-LINE
           IF WS-OPERATION = SPACES
               MOVE 'CALC' TO WS-OPERATION
           END-IF
           PERFORM FE-INIT-RATES
           EVALUATE WS-OPERATION
               WHEN 'CALC'   PERFORM FE-DO-CALC
               WHEN 'REPORT' PERFORM FE-DO-REPORT
               WHEN 'BATCH'  PERFORM FE-DO-BATCH
               WHEN OTHER
                   DISPLAY "FEE|ERROR|UNKNOWN-OP|" WS-OPERATION
                   MOVE '03' TO WS-RESULT-CODE
           END-EVALUATE
           DISPLAY "RESULT|" WS-RESULT-CODE
           STOP RUN.

      *> FE-INIT-RATES: Overwrite copybook with hardcoded 1986 rates
       FE-INIT-RATES.
      *>   RBJ: "Premium = base + 0.50%" — code adds 0.65%. Trust code.
           MOVE 'VISA' TO FEE-NETWORK-CODE(1)
           MOVE WS-VISA-RATE TO FEE-BASE-RATE(1)
           MOVE WS-PER-TX-VISA TO FEE-PER-TX-CENTS(1)
           COMPUTE FEE-PREMIUM-RATE(1) = WS-VISA-RATE + 0.0065
           MOVE 'MC  ' TO FEE-NETWORK-CODE(2)
           MOVE WS-MC-RATE TO FEE-BASE-RATE(2)
           MOVE WS-PER-TX-MC TO FEE-PER-TX-CENTS(2)
           COMPUTE FEE-PREMIUM-RATE(2) = WS-MC-RATE + 0.0065
           MOVE 'AMEX' TO FEE-NETWORK-CODE(3)
           MOVE WS-AMEX-RATE TO FEE-BASE-RATE(3)
           MOVE WS-PER-TX-AMEX TO FEE-PER-TX-CENTS(3)
           COMPUTE FEE-PREMIUM-RATE(3) = WS-AMEX-RATE + 0.0085
           MOVE 'DISC' TO FEE-NETWORK-CODE(4)
           MOVE WS-DISC-RATE TO FEE-BASE-RATE(4)
           MOVE WS-PER-TX-DISC TO FEE-PER-TX-CENTS(4)
           COMPUTE FEE-PREMIUM-RATE(4) = WS-DISC-RATE + 0.0045
      *>   Tier boundaries (magic numbers — duplicated in FE-APPLY-MARKUP)
           MOVE 0 TO FEE-TIER-MIN-VOL(1)
           MOVE 10000 TO FEE-TIER-MAX-VOL(1)
           MOVE WS-BPS-1 TO FEE-TIER-BPS(1)
           MOVE 10000 TO FEE-TIER-MIN-VOL(2)
           MOVE 100000 TO FEE-TIER-MAX-VOL(2)
           MOVE WS-BPS-2 TO FEE-TIER-BPS(2)
           MOVE 100000 TO FEE-TIER-MIN-VOL(3)
           MOVE 1000000 TO FEE-TIER-MAX-VOL(3)
           MOVE WS-BPS-3 TO FEE-TIER-BPS(3)
      *>   ACS 1994: Tier 4 — "next quarter" (30 years ago)
           MOVE 1000000 TO FEE-TIER-MIN-VOL(4)
           MOVE 9999999 TO FEE-TIER-MAX-VOL(4)
           MOVE 0 TO FEE-TIER-BPS(4)
      *>   MCC premium ranges (airlines, lodging, auto rental)
           MOVE 3000 TO WS-MCC-LO(1)
           MOVE 3299 TO WS-MCC-HI(1)
           MOVE 3500 TO WS-MCC-LO(2)
           MOVE 3999 TO WS-MCC-HI(2)
           MOVE 7000 TO WS-MCC-LO(3)
           MOVE 7099 TO WS-MCC-HI(3)
           MOVE 'Y' TO WS-MCC-PREMIUM(1) WS-MCC-PREMIUM(2)
                        WS-MCC-PREMIUM(3)
           MOVE 0.0100 TO FEE-INTL-UPLIFT-PCT
           MOVE 0.0050 TO FEE-FX-SPREAD-PCT
           SET FEE-IS-DOMESTIC TO TRUE
           MOVE 0 TO FEE-CALC-INTERCHANGE FEE-CALC-MARKUP
                     FEE-CALC-CROSS-BORDER FEE-CALC-TOTAL FEE-TX-COUNT
           SET FEE-OK TO TRUE.

      *> ── FILE STATUS CODES (memorize these five) ─────────────────
      *>   00 = success. 10 = end of file. 22 = duplicate key on
      *>   write. 23 = record not found ("the first code every
      *>   banking COBOL programmer memorizes"). 35 = file not
      *>   found at OPEN (typically a missing DD in JCL). These
      *>   five codes account for 95% of production file I/O
      *>   issues. Unchecked FILE STATUS after any I/O verb means
      *>   errors propagate silently — a failed READ returns stale
      *>   data from the previous successful read.
       FE-DO-CALC.
           OPEN INPUT MERCHANT-FILE
           IF WS-MERCH-STATUS NOT = '00'
               DISPLAY "FEE|ERROR|MERCHANTS.DAT|" WS-MERCH-STATUS
               MOVE '99' TO WS-RESULT-CODE
               STOP RUN
           END-IF
           READ MERCHANT-FILE
               AT END
                   DISPLAY "FEE|ERROR|NO-MERCHANTS"
                   MOVE '03' TO WS-RESULT-CODE
                   CLOSE MERCHANT-FILE
                   STOP RUN
           END-READ
           MOVE MERCH-ID TO WS-CUR-MERCH-ID
           MOVE MERCH-FEE-TIER TO WS-CUR-FEE-TIER
           MOVE MERCH-MCC-CODE TO WS-CUR-MCC
           MOVE MERCH-MONTHLY-VOL TO WS-CUR-MONTHLY-VOL
           CLOSE MERCHANT-FILE
           PERFORM FE-COUNT-TX
           PERFORM FE-CALC-INTERCHANGE
           PERFORM FE-APPLY-MARKUP
           PERFORM FE-CROSS-BORDER-UPLIFT
      *>   1989: This REPLACES everything computed above
           PERFORM FE-BLEND-OVERRIDE
           PERFORM FE-WRITE-RESULT.

       FE-COUNT-TX.
           MOVE 0 TO WS-MERCH-TX-COUNT WS-MERCH-TX-TOTAL
           MOVE 'N' TO WS-TX-EOF
           OPEN INPUT TRANSACTION-FILE
           IF WS-TX-STATUS NOT = '00'
               GO TO FE-COUNT-TX-EXIT
           END-IF
           PERFORM UNTIL WS-TX-DONE
               READ TRANSACTION-FILE
                   AT END SET WS-TX-DONE TO TRUE
                   NOT AT END
                       IF TX-IN-MERCH-ID = WS-CUR-MERCH-ID
                         AND TX-IN-STATUS = '00'
                           ADD 1 TO WS-MERCH-TX-COUNT
                           ADD TX-IN-AMOUNT TO WS-MERCH-TX-TOTAL
                       END-IF
               END-READ
           END-PERFORM
           CLOSE TRANSACTION-FILE.
       FE-COUNT-TX-EXIT.
           EXIT.

      *> FE-CALC-INTERCHANGE: O(48) triple-nested loop. Blend trashes it.
      *>   NUMERIC OVERFLOW: FEE-CALC-TOTAL (PIC S9(7)V99) overflows
      *>   silently if a single transaction exceeds $99,999.99 and all
      *>   three surcharges apply. Interchange + markup + cross-border
      *>   on a $100K transaction at 2.9% + 50bps + 1.5% = ~$4,400,
      *>   well within range. But 10,000 transactions at $100K each
      *>   produces $44M in fees — truncated to $4,400,000.00 with
      *>   the leading digits silently lost. No ON SIZE ERROR anywhere.
      *>
      *>   IMPLIED DECIMAL TRAP: The COMPUTE statements below use
      *>   ROUNDED but not ON SIZE ERROR. The safe pattern is:
      *>     COMPUTE WS-RESULT = WS-A * WS-B
      *>         ROUNDED
      *>         ON SIZE ERROR PERFORM ERROR-HANDLER
      *>     END-COMPUTE
      *>   This program uses NONE of these safeguards consistently.
       FE-CALC-INTERCHANGE.
           MOVE 0 TO FEE-CALC-INTERCHANGE WS-TX-FEE
           MOVE 'N' TO WS-NET-MATCHED WS-IS-PREMIUM
           COMPUTE WS-NET-IDX = FUNCTION MOD(WS-CUR-MCC, 4) + 1
           PERFORM VARYING WS-NET-IDX FROM 1 BY 1
               UNTIL WS-NET-IDX > 4 OR WS-NET-MATCHED = 'Y'
               PERFORM VARYING WS-TIER-IDX FROM 1 BY 1
                   UNTIL WS-TIER-IDX > 4 OR WS-NET-MATCHED = 'Y'
                   IF WS-CUR-FEE-TIER = WS-TIER-IDX
                       PERFORM VARYING WS-MCC-IDX FROM 1 BY 1
                           UNTIL WS-MCC-IDX > 3
                           IF WS-CUR-MCC >= WS-MCC-LO(WS-MCC-IDX)
                             AND WS-CUR-MCC <=
                                 WS-MCC-HI(WS-MCC-IDX)
                               MOVE 'Y' TO WS-IS-PREMIUM
                           END-IF
                       END-PERFORM
                       IF WS-IS-PREMIUM = 'Y'
                           MOVE FEE-PREMIUM-RATE(WS-NET-IDX)
                               TO WS-RATE-WORK
                       ELSE
                           MOVE FEE-BASE-RATE(WS-NET-IDX)
                               TO WS-RATE-WORK
                       END-IF
      *>               "rate * volume + per-tx" (uses tx total, not vol)
                       COMPUTE WS-TX-FEE ROUNDED =
                           (WS-MERCH-TX-TOTAL * WS-RATE-WORK)
                           + (WS-MERCH-TX-COUNT
                              * FEE-PER-TX-CENTS(WS-NET-IDX) / 100)
                       MOVE WS-TX-FEE TO FEE-CALC-INTERCHANGE
                       MOVE 'Y' TO WS-NET-MATCHED
                   END-IF
               END-PERFORM
           END-PERFORM
           IF WS-NET-MATCHED = 'N'
               COMPUTE FEE-CALC-INTERCHANGE ROUNDED =
                   (WS-MERCH-TX-TOTAL * 0.0175)
                   + (WS-MERCH-TX-COUNT * 10 / 100)
           END-IF.

       FE-APPLY-MARKUP.
           MOVE 0 TO FEE-CALC-MARKUP
           MOVE 'N' TO WS-TIER-MATCHED
           IF WS-CUR-MONTHLY-VOL < 10000
               COMPUTE FEE-CALC-MARKUP ROUNDED =
                   WS-MERCH-TX-TOTAL * WS-BPS-1 / 10000
               MOVE 'Y' TO WS-TIER-MATCHED
           END-IF
           IF WS-TIER-MATCHED = 'N'
             AND WS-CUR-MONTHLY-VOL < 100000
               COMPUTE FEE-CALC-MARKUP ROUNDED =
                   WS-MERCH-TX-TOTAL * WS-BPS-2 / 10000
               MOVE 'Y' TO WS-TIER-MATCHED
           END-IF
           IF WS-TIER-MATCHED = 'N'
               COMPUTE FEE-CALC-MARKUP ROUNDED =
                   WS-MERCH-TX-TOTAL * WS-BPS-3 / 10000
           END-IF.

      *> FE-CROSS-BORDER-UPLIFT: Always domestic. Int'l never runs.
       FE-CROSS-BORDER-UPLIFT.
           MOVE 0 TO FEE-CALC-CROSS-BORDER
           IF FEE-IS-INTL
               COMPUTE FEE-CALC-CROSS-BORDER ROUNDED =
                   WS-MERCH-TX-TOTAL *
                   (FEE-INTL-UPLIFT-PCT + FEE-FX-SPREAD-PCT)
           END-IF.

      *> FE-BLEND-OVERRIDE: "Temporary" 2.9%+$0.30 from 1989. 'Y' 37yr.
      *>   TEMPORARY for Q2 1989. Will remove when interchange+
      *>   negotiations complete. Status: 37 years and counting.
      *>   RBJ 1989-06-30: "Leaving blend for Q3. Mark will finish
      *>   the interchange+ contract." Mark left in 1990.
       FE-BLEND-OVERRIDE.
           IF FEE-BLEND-FLAG = 'Y'
      *>       "Flat 2.9% + $0.30 — simple, clean, temporary"
               COMPUTE FEE-CALC-INTERCHANGE ROUNDED =
                   WS-MERCH-TX-TOTAL * FEE-BLEND-RATE
               COMPUTE FEE-CALC-MARKUP ROUNDED =
                   WS-MERCH-TX-COUNT * FEE-BLEND-PER-TX / 100
               MOVE 0 TO FEE-CALC-CROSS-BORDER
           END-IF
           COMPUTE FEE-CALC-TOTAL =
               FEE-CALC-INTERCHANGE + FEE-CALC-MARKUP
               + FEE-CALC-CROSS-BORDER.

       FE-WRITE-RESULT.
           MOVE FEE-CALC-INTERCHANGE TO WS-FMT-IC
           MOVE FEE-CALC-MARKUP TO WS-FMT-MK
           MOVE FEE-CALC-TOTAL TO WS-FMT-TOT
           MOVE WS-MERCH-TX-COUNT TO WS-FMT-CNT
           DISPLAY "FEE|" WS-CUR-MERCH-ID "|"
               WS-FMT-CNT "|" WS-FMT-IC "|"
               WS-FMT-MK "|" WS-FMT-TOT.

      *> RBJ: "REPORT and BATCH produce same output"
       FE-DO-REPORT.
           PERFORM FE-DO-BATCH.

      *> FE-DO-BATCH: SORT by tier then blend ignores tier. Ironic.
      *>   SORT FAILURE RECOVERY: If SORT abends mid-execution, the
      *>   SORT-WORK temporary file remains locked. On IBM z/OS this
      *>   meant an IPL (Initial Program Load) — a 2-hour system
      *>   restart. We lost the Sunday evening batch window twice in
      *>   1988 to SORT-WORK locks. Modern z/OS has RESET SORTWORK
      *>   but old JCL never got updated.
      *>   ABEND CODES: S0C7 = data exception (invalid packed decimal,
      *>   the #1 most common COBOL abend), S0C4 = protection exception
      *>   (bad pointer/subscript), S322 = time exceeded (infinite loop).
      *>
      *>   EBCDIC SORT ORDER: The SORT verb uses the platform's native
      *>   collating sequence. On EBCDIC: 'a' < 'A' < '1'. On ASCII:
      *>   '1' < 'A' < 'a'. Merchant IDs sorted on z/OS will be in
      *>   DIFFERENT order when this program runs under GnuCOBOL (ASCII).
      *>   PROGRAM COLLATING SEQUENCE IS can override this, but RBJ
      *>   never specified one — a latent migration bug.
       FE-DO-BATCH.
           MOVE 0 TO WS-BATCH-FEE-TOTAL WS-BATCH-MERCH-COUNT
                     WS-BATCH-TX-COUNT WS-SORT-TX-COUNT
           SORT SORT-WORK
               ON ASCENDING KEY SORT-FEE-TIER
               ON ASCENDING KEY SORT-MERCH-ID
               INPUT PROCEDURE IS FE-SORT-INPUT
                   THRU FE-SORT-INPUT-EXIT
               OUTPUT PROCEDURE IS FE-SORT-OUTPUT
                   THRU FE-SORT-OUTPUT-EXIT
           DISPLAY "FEE-TOTAL|"
               WS-BATCH-TX-COUNT "|" WS-FMT-BTOT.

      *> FE-SORT-INPUT: O(M*T) scan. RBJ: "Run overnight."
      *>   BATCH ORDERING ASSUMPTION: INPUT PROCEDURE assumes merchants
      *>   in MERCHANTS.DAT are pre-sorted by MERCH-ID. If not, the
      *>   SORT OUTPUT PROCEDURE groups by SORT-MERCH-ID — but the
      *>   INPUT scan re-reads TRANSACT.DAT once per merchant (O(M*T)).
      *>   On a real mainframe with 50,000 merchants and 2M daily
      *>   transactions, this takes hours. Nobody dared optimize it
      *>   because the SORT INPUT PROCEDURE's RELEASE ordering is
      *>   sensitive: RELEASE in the wrong MCC order produces silently
      *>   incorrect tier assignments in the OUTPUT PROCEDURE.
       FE-SORT-INPUT.
           OPEN INPUT MERCHANT-FILE
           IF WS-MERCH-STATUS NOT = '00'
               DISPLAY "FEE|ERROR|SORT-INPUT|" WS-MERCH-STATUS
               MOVE '99' TO WS-RESULT-CODE
               GO TO FE-SORT-INPUT-EXIT
           END-IF
           MOVE 'N' TO WS-MERCH-EOF
           PERFORM UNTIL WS-MERCH-DONE
               READ MERCHANT-FILE
                   AT END SET WS-MERCH-DONE TO TRUE
                   NOT AT END
                       IF MERCH-ACTIVE
                           MOVE MERCH-ID TO WS-CUR-MERCH-ID
                           MOVE MERCH-FEE-TIER TO WS-CUR-FEE-TIER
                           MOVE MERCH-MCC-CODE TO WS-CUR-MCC
                           OPEN INPUT TRANSACTION-FILE
                           IF WS-TX-STATUS = '00'
                               MOVE 'N' TO WS-TX-EOF
                               PERFORM UNTIL WS-TX-DONE
                                   READ TRANSACTION-FILE
                                     AT END
                                       SET WS-TX-DONE TO TRUE
                                     NOT AT END
                                       IF TX-IN-MERCH-ID =
                                         WS-CUR-MERCH-ID
                                         AND TX-IN-STATUS = '00'
                                           MOVE WS-CUR-FEE-TIER
                                             TO SORT-FEE-TIER
                                           MOVE WS-CUR-MERCH-ID
                                             TO SORT-MERCH-ID
                                           MOVE TX-IN-AMOUNT
                                             TO SORT-TX-AMOUNT
                                           MOVE WS-CUR-MCC
                                             TO SORT-MCC-CODE
                                           COMPUTE SORT-NETWORK-IDX =
                                             FUNCTION MOD(
                                             WS-CUR-MCC, 4) + 1
                                           RELEASE SORT-RECORD
                                           ADD 1 TO WS-SORT-TX-COUNT
                                       END-IF
                                   END-READ
                               END-PERFORM
                               CLOSE TRANSACTION-FILE
                           END-IF
                       END-IF
               END-READ
           END-PERFORM
           CLOSE MERCHANT-FILE.
       FE-SORT-INPUT-EXIT.
           EXIT.

      *> FE-SORT-OUTPUT: RETURN sorted records, group by merchant.
       FE-SORT-OUTPUT.
           MOVE 'N' TO WS-SORT-EOF
           MOVE SPACES TO WS-HOLD-MERCH-ID
           MOVE 0 TO WS-MERCH-TX-COUNT WS-MERCH-TX-TOTAL
           PERFORM UNTIL WS-SORT-DONE
               RETURN SORT-WORK
                   AT END
                       SET WS-SORT-DONE TO TRUE
                       IF WS-HOLD-MERCH-ID NOT = SPACES
                           PERFORM FE-SORT-CALC-MERCHANT
                       END-IF
                   NOT AT END
                       IF SORT-MERCH-ID NOT = WS-HOLD-MERCH-ID
                           IF WS-HOLD-MERCH-ID NOT = SPACES
                               PERFORM FE-SORT-CALC-MERCHANT
                           END-IF
                           MOVE SORT-MERCH-ID TO WS-HOLD-MERCH-ID
                                                 WS-CUR-MERCH-ID
                           MOVE SORT-FEE-TIER TO WS-CUR-FEE-TIER
                           MOVE SORT-MCC-CODE TO WS-CUR-MCC
                           MOVE 0 TO WS-MERCH-TX-COUNT
                                     WS-MERCH-TX-TOTAL
                                     WS-CUR-MONTHLY-VOL
                       END-IF
                       ADD 1 TO WS-MERCH-TX-COUNT
                       ADD SORT-TX-AMOUNT TO WS-MERCH-TX-TOTAL
               END-RETURN
           END-PERFORM.
       FE-SORT-OUTPUT-EXIT.
           EXIT.

       FE-SORT-CALC-MERCHANT.
           PERFORM FE-CALC-INTERCHANGE
           PERFORM FE-APPLY-MARKUP
           PERFORM FE-CROSS-BORDER-UPLIFT
           PERFORM FE-BLEND-OVERRIDE
           PERFORM FE-WRITE-RESULT
           ADD FEE-CALC-TOTAL TO WS-BATCH-FEE-TOTAL
           ADD 1 TO WS-BATCH-MERCH-COUNT
           ADD WS-MERCH-TX-COUNT TO WS-BATCH-TX-COUNT
           MOVE WS-BATCH-FEE-TOTAL TO WS-FMT-BTOT.

      *> ── DEAD PARAGRAPHS ──────────────────────────────────────────
      *> These paragraphs are never PERFORMed, GO TO'd, or ALTERed.
      *> They exist as archaeological artifacts of abandoned features.

      *> FE-DEAD-TIER-5: Enterprise tier pricing. ACS 1994-07-22.
      *> "Adding tier 5 for merchants processing >$10M/month.
      *> Negative basis points — we PAY them to use our network.
      *> Will wire into FE-APPLY-MARKUP next quarter."
      *> ACS transferred to the dispute team in August 1994.
      *> "Next quarter" never came.
       FE-DEAD-TIER-5.
           DISPLAY "FEE|TIER5|ENTERPRISE"
           MOVE 0 TO FEE-CALC-MARKUP
           MOVE 'Y' TO WS-TIER-MATCHED.
       FE-DEAD-TIER-5-EXIT.
           EXIT.

      *> FE-DEAD-REFUND-CALC: Refund fee reversal. RBJ 1988-03-15.
      *> "When a merchant issues a refund, we should reverse the
      *> interchange fee. Legal says we can keep the per-tx fee."
      *> Legal actually said "no refund fee reversal at all."
      *> RBJ wrote the code anyway. It was never called.
       FE-DEAD-REFUND-CALC.
           DISPLAY "FEE|REFUND|REVERSAL"
           MOVE 0 TO WS-DEAD-REFUND-PCT.
       FE-DEAD-REFUND-CALC-EXIT.
           EXIT.
