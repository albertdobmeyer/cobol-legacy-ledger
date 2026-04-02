      *>================================================================*
      *>  EDUCATIONAL NOTE: This program contains INTENTIONAL anti-patterns
      *>  for teaching purposes. See KNOWN_ISSUES.md for the full catalog.
      *>================================================================*
      *>  Program:     RISKCHK.cob
      *>  System:      PRE-TRANSACTION RISK ENGINE — Fraud & Velocity
      *>  Author:      KMW (onshore 2008), Offshore Team (2009-2012)
      *>  Written:     2008-06-10 (Linux/GnuCOBOL migration from z/OS)
      *>
      *>  JCL: //RISK0100 JOB (ACCT),'RISK CHECK',CLASS=B
      *>       //STEP01   EXEC PGM=RISKCHK,PARM='CHECK'
      *>
      *>  Change Log:
      *>    2008-06-10  KMW  Initial — single-txn risk scoring
      *>    2008-09-15  KMW  Added velocity check (per-hour)
      *>    2008-11-22  KMW  Added MCC risk tiers, INSPECT TALLYING
      *>    2009-03-01  OFS  "Improved" velocity (per-day). Did NOT
      *>                     remove KMW's. Both run. Scores add up.
      *>    2009-07-14  OFS  RK-ML-SCORE placeholder (returns 50)
      *>    2010-02-28  OFS  Added SCAN operation
      *>    2010-11-05  KMW  Added PROFILE operation (audit finding)
      *>    2011-04-20  OFS  RK-AMOUNT-VALIDATION-ROUTINE (duplicate)
      *>    2012-01-15  OFS  "Final cleanup" — dead vars, no fixes
      *>
      *>  CONFLICTS: (1) Velocity — KMW >5/hr vs OFS >20/day, both
      *>  run, scores stack. (2) Risk tiers — KMW HIGH=4-5, OFS
      *>  RISKY=3-5, tier 3 scored differently per path.
      *>  NAMING: KMW=RK-CHECK-xxx, OFS=RK-xxx-ROUTINE/V2.
      *>================================================================*

       IDENTIFICATION DIVISION.
       PROGRAM-ID. RISKCHK.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MERCHANT-FILE ASSIGN TO "MERCHANTS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-MERCH-STATUS.
           SELECT TRANSACTION-FILE ASSIGN TO "TRANSACT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-TRANS-STATUS.
           SELECT RISKFLAG-FILE ASSIGN TO "RISKFLAGS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FLAG-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MERCHANT-FILE.
           COPY "MERCHREC.cpy".
       FD  TRANSACTION-FILE.
           COPY "TRANSREC.cpy".
       FD  RISKFLAG-FILE.
       01  RISKFLAG-RECORD            PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUSES.
           05  WS-MERCH-STATUS        PIC X(2).
           05  WS-TRANS-STATUS        PIC X(2).
           05  WS-FLAG-STATUS         PIC X(2).
       COPY "COMCODE.cpy".
       01  WS-EOF-MERCH               PIC X(1) VALUE 'N'.
           88  WS-MERCH-EOF           VALUE 'Y'.
       01  WS-EOF-TRANS               PIC X(1) VALUE 'N'.
           88  WS-TRANS-EOF           VALUE 'Y'.
       01  WS-CMD-ARG                 PIC X(20).
       01  WS-OPERATION               PIC X(8).
           88  OP-CHECK               VALUE 'CHECK'.
           88  OP-SCAN                VALUE 'SCAN'.
           88  OP-PROFILE             VALUE 'PROFILE'.
      *> ── Input (CHECK: pipe-delimited ACCT|AMOUNT|MCC|DESC) ─
       01  WS-INPUT-LINE              PIC X(200).
       01  WS-INPUT-ACCT              PIC X(10).
       01  WS-INPUT-AMOUNT            PIC S9(10)V99 VALUE 0.
      *>   INPUT VALIDATION APATHY: WS-INPUT-AMOUNT is never validated
      *>   for zero or negative values. A negative amount produces
      *>   negative risk points, REDUCING the total score. A money
      *>   launderer could submit -$50K to offset a flagged $50K
      *>   transaction's score — net zero, no flag raised.
       01  WS-INPUT-MCC               PIC 9(4) VALUE 0.
       01  WS-INPUT-DESC              PIC X(40).
      *> ── KMW: Risk score 0-100. Over 75 = flag. ────────────
      *>   NUMERIC OVERFLOW: PIC 9(3) max = 999. Double-scored
      *>   velocity (KMW 20 + OFS 25) + amount (KMW 35 + OFS 30)
      *>   + gambling MCC (20+25) + keywords (15) + tier (25+10+15)
      *>   = 220 max. But extreme cases with high keyword counts
      *>   and all paths firing can exceed 999 — wrapping to 0,
      *>   which CLEARS a legitimately flagged transaction.
      *>
      *>   FIELD REUSE: Both KMW and offshore paths accumulate into
      *>   this same field without resetting between scoring phases.
      *>   This is the ROOT CAUSE of the double-scoring issue — not
      *>   a feature, but neither developer wanted to refactor.
       01  WS-RISK-SCORE              PIC 9(3) VALUE 0.
       01  WS-RISK-REASON             PIC X(60) VALUE SPACES.
       01  WS-RISK-THRESHOLD          PIC 9(3) VALUE 75.
      *> ── KMW: 88-level tiers. 4-5 = high risk. ─────────────
      *>   LEVEL 88 — COBOL'S MOST UNDERAPPRECIATED FEATURE:
      *>   88-levels allocate no storage. They attach boolean
      *>   conditions to the parent field, enabling:
      *>     IF RK-HIGH-RISK    (instead of IF WS-TIER-CLASS >= 4)
      *>     SET RK-HIGH-RISK TO TRUE  (assigns 4 to parent)
      *>   They support multiple values: VALUE 'A' 'B' 'C'
      *>   And ranges: VALUE 60 THRU 100
      *>   Centralizes validation in one place. Change the
      *>   threshold from 4-5 to 3-5 here and every IF in the
      *>   program picks up the change automatically.
       01  WS-TIER-CLASS              PIC 9(1) VALUE 0.
           88  RK-LOW-RISK            VALUE 1 THRU 2.
           88  RK-MEDIUM-RISK         VALUE 3.
           88  RK-HIGH-RISK           VALUE 4 THRU 5.
      *> ── OFS: DUPLICATE 88-level. 3-5 = risky. CONFLICT! ───
       01  WS-TIER-LEVEL              PIC 9(1) VALUE 0.
           88  RK-SAFE                VALUE 1 THRU 2.
           88  RK-RISKY               VALUE 3 THRU 5.
           88  RK-CRITICAL            VALUE 5.
      *> ── KMW: Velocity per-hour (>5/hr = burst fraud) ──────
       01  WS-HOURLY-COUNT            PIC 9(3) VALUE 0.
       01  WS-HOURLY-THRESHOLD        PIC 9(3) VALUE 5.
       01  WS-CURRENT-HOUR            PIC 9(2) VALUE 0.
       01  WS-TXN-HOUR                PIC 9(2) VALUE 0.
      *> ── OFS: Velocity per-day (>20/day). ALSO runs. ───────
       01  WS-DAILY-TXN-CTR           PIC 9(5) VALUE 0.
       01  WS-DAILY-THRESHOLD         PIC 9(5) VALUE 20.
       01  WS-CURRENT-DATE-8          PIC 9(8) VALUE 0.
       01  WS-TXN-DATE-CMP            PIC 9(8) VALUE 0.
      *> ── OFS 2012: Dead vars — "future geo-fencing" ────────
       01  WS-GEO-LATITUDE            PIC S9(3)V9(6) VALUE 0.
       01  WS-GEO-LONGITUDE           PIC S9(3)V9(6) VALUE 0.
      *> ── INSPECT TALLYING counters ─────────────────────────
       01  WS-SUSPICIOUS-WORDS        PIC 9(3) VALUE 0.
       01  WS-CASH-TALLY              PIC 9(3) VALUE 0.
       01  WS-WIRE-TALLY              PIC 9(3) VALUE 0.
       01  WS-URGENT-TALLY            PIC 9(3) VALUE 0.
       01  WS-OFFSHORE-TALLY          PIC 9(3) VALUE 0.
       01  WS-CRYPTO-TALLY            PIC 9(3) VALUE 0.
       01  WS-MERCH-FOUND             PIC X(1) VALUE 'N'.
           88  WS-MERCH-LOCATED       VALUE 'Y'.
       01  WS-LOOKUP-MCC              PIC 9(4) VALUE 0.
      *> ── OFS: ML score — always 50. CICS never funded. ─────
       01  WS-ML-SCORE                PIC 9(3) VALUE 0.
       01  WS-ML-READY                PIC X(1) VALUE 'N'.
           88  WS-ML-AVAILABLE        VALUE 'Y'.
       01  WS-SCAN-COUNT              PIC 9(5) VALUE 0.
       01  WS-FLAG-COUNT              PIC 9(5) VALUE 0.
       01  WS-DISPLAY-AMOUNT          PIC Z(9)9.99.
       01  WS-DISPLAY-SCORE           PIC ZZ9.
      *> ── MCC ranges (KMW hardcoded) ────────────────────────
       01  WS-MCC-GAMBLING-LOW        PIC 9(4) VALUE 7800.
       01  WS-MCC-GAMBLING-HIGH       PIC 9(4) VALUE 7999.
       01  WS-MCC-MONEY-SVC-LOW       PIC 9(4) VALUE 6050.
       01  WS-MCC-MONEY-SVC-HIGH      PIC 9(4) VALUE 6051.
      *> ── Amount thresholds (SAR = $10K, flag at $9.5K) ─────
       01  WS-SAR-THRESHOLD           PIC S9(10)V99 VALUE 9500.00.
       01  WS-HIGH-AMOUNT             PIC S9(10)V99 VALUE 5000.00.
       01  WS-MEDIUM-AMOUNT           PIC S9(10)V99 VALUE 2000.00.
       01  WS-CURRENT-DATETIME.
           05  WS-CURR-DATE          PIC 9(8).
           05  WS-CURR-TIME.
               10  WS-CURR-HH        PIC 9(2).
               10  WS-CURR-REST      PIC 9(6).
           05  WS-CURR-GMT-DIFF      PIC S9(4).
       01  WS-OUTPUT-LINE             PIC X(200).

      *> ── DEAD FIELDS (unreferenced by executable code) ────────
      *> Regulatory compliance heritage fields. On a real banking
      *> system, these would drive CTR/SAR/OFAC batch programs.
       01  WS-DEAD-CTR-THRESHOLD     PIC S9(10)V99 VALUE 10000.00.
      *>   Currency Transaction Report trigger: any customer with
      *>   same-day cash aggregate exceeding $10,000 gets a CTR
      *>   filed with FinCEN. This field was meant to be configurable.
       01  WS-DEAD-SAR-STRUCTURING   PIC 9(3) VALUE 0.
      *>   SAR structuring counter: multiple sub-$10K transactions
      *>   ("structuring") triggers Suspicious Activity Report.
       01  WS-DEAD-OFAC-MATCH-SCORE  PIC 9(3) VALUE 0.
      *>   OFAC SDN list fuzzy matching score (0-100). Exact match
      *>   on name = 100; phonetic match = 70+. > 85 = auto-block.
       01  WS-DEAD-SWIFT-MSG-TYPE    PIC X(5) VALUE SPACES.
      *>   SWIFT message format: MT103 = customer transfers,
      *>   MT202 = interbank, MT940 = statements. ISO 20022
      *>   transition: MT103→pacs.008, MT940→camt.053 (mandatory
      *>   for cross-border payments since Nov 2025).
       01  WS-DEAD-DEVICE-ID         PIC X(32) VALUE SPACES.
      *>   OFS 2011: "device fingerprinting for mobile." Never funded.
      *> Contradicting 88-level: overrides the program's own threshold
       01  WS-DEAD-LOW-RISK-FLAG     PIC X(1) VALUE 'N'.
           88  WS-DEAD-OVERRIDE-SAFE VALUE 'Y'.
      *>   If this were checked, a score of 0-25 would be "safe" even
      *>   though WS-RISK-THRESHOLD is 75. These two definitions of
      *>   "safe" are incompatible — one says <25, the other says <75.

       PROCEDURE DIVISION.
       RK-MAIN.
           ACCEPT WS-CMD-ARG FROM COMMAND-LINE
           MOVE FUNCTION UPPER-CASE(WS-CMD-ARG) TO WS-OPERATION
           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATETIME
           MOVE WS-CURR-DATE TO WS-CURRENT-DATE-8
           MOVE WS-CURR-HH TO WS-CURRENT-HOUR
           EVALUATE TRUE
               WHEN OP-CHECK    PERFORM RK-PROCESS-CHECK
               WHEN OP-SCAN     PERFORM RK-PROCESS-SCAN
               WHEN OP-PROFILE  PERFORM RK-PROCESS-PROFILE
               WHEN OTHER
                   DISPLAY "RISK|ERROR|UNKNOWN-OP|" WS-OPERATION
                   DISPLAY "RESULT|03"
                   STOP RUN
           END-EVALUATE
           STOP RUN.

      *> ── CHECK: Single transaction risk assessment ─────────
       RK-PROCESS-CHECK.
           ACCEPT WS-INPUT-LINE FROM STANDARD-INPUT
           UNSTRING WS-INPUT-LINE DELIMITED BY "|"
               INTO WS-INPUT-ACCT WS-INPUT-AMOUNT
                    WS-INPUT-MCC  WS-INPUT-DESC
           END-UNSTRING
           MOVE 0 TO WS-RISK-SCORE
           MOVE SPACES TO WS-RISK-REASON
           PERFORM RK-CHECK-AMOUNT
           PERFORM RK-CHECK-MCC
           PERFORM RK-CHECK-KEYWORDS
      *>   KMW's per-hour velocity runs, then OFS per-day ALSO runs
           PERFORM RK-VELOCITY-CHECK
           PERFORM RK-VELOCITY-CHECK-V2
           PERFORM RK-ML-SCORE
      *>   OFS duplicate amount check — KMW refused to remove his
           PERFORM RK-AMOUNT-VALIDATION-ROUTINE
           PERFORM RK-EVALUATE-RISK
           DISPLAY "RESULT|00".
      *> ── SCAN: Batch daily risk review ─────────────────────
      *>   BATCH ORDERING ASSUMPTION: The merchant file must be
      *>   pre-sorted by MERCH-ID for PROFILE's sequential lookup
      *>   to work. Duplicate MERCH-IDs cause the first match to
      *>   shadow all others — a merchant with two records gets
      *>   profiled using only their earliest entry.
      *>
      *>   FILE STATUS: This paragraph checks WS-TRANS-STATUS after
      *>   OPEN but not after each READ. A corrupted record mid-file
      *>   returns FILE STATUS '46' (sequential read after failed
      *>   read) — but we never check it, so we process the stale
      *>   record buffer from the last successful READ.
       RK-PROCESS-SCAN.
           OPEN INPUT TRANSACTION-FILE
           IF WS-TRANS-STATUS NOT = '00'
               DISPLAY "RISK|ERROR|TRANS-FILE|" WS-TRANS-STATUS
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
           OPEN OUTPUT RISKFLAG-FILE
           IF WS-FLAG-STATUS NOT = '00'
               CLOSE TRANSACTION-FILE
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
           MOVE 'N' TO WS-EOF-TRANS
           MOVE 0 TO WS-SCAN-COUNT WS-FLAG-COUNT
           PERFORM RK-SCAN-LOOP UNTIL WS-TRANS-EOF
           DISPLAY "RISK|SCAN-DONE|" WS-SCAN-COUNT "|" WS-FLAG-COUNT
           CLOSE TRANSACTION-FILE
           CLOSE RISKFLAG-FILE
           DISPLAY "RESULT|00".
       RK-SCAN-LOOP.
           READ TRANSACTION-FILE
               AT END SET WS-TRANS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-SCAN-COUNT
                   MOVE TRANS-ACCT-ID TO WS-INPUT-ACCT
                   MOVE TRANS-AMOUNT TO WS-INPUT-AMOUNT
                   MOVE TRANS-DESC TO WS-INPUT-DESC
      *>           HACK: No MCC in txn record. MCC checks useless here.
                   MOVE 0 TO WS-INPUT-MCC
                   MOVE 0 TO WS-RISK-SCORE
                   MOVE SPACES TO WS-RISK-REASON
                   PERFORM RK-CHECK-AMOUNT
                   PERFORM RK-CHECK-KEYWORDS
                   PERFORM RK-AMOUNT-VALIDATION-ROUTINE
                   IF WS-RISK-SCORE >= WS-RISK-THRESHOLD
                       ADD 1 TO WS-FLAG-COUNT
                       MOVE WS-INPUT-AMOUNT TO WS-DISPLAY-AMOUNT
                       MOVE WS-RISK-SCORE TO WS-DISPLAY-SCORE
                       STRING "RISK|FLAG|"
                           TRANS-ACCT-ID DELIMITED BY SPACES "|"
                           WS-DISPLAY-AMOUNT DELIMITED BY SPACES "|"
                           WS-DISPLAY-SCORE DELIMITED BY SPACES "|"
                           WS-RISK-REASON DELIMITED BY SPACES
                           INTO WS-OUTPUT-LINE
                       END-STRING
                       WRITE RISKFLAG-RECORD FROM WS-OUTPUT-LINE
                       DISPLAY WS-OUTPUT-LINE
                   END-IF
           END-READ.
      *> ── PROFILE: Merchant risk profile by MCC ─────────────
       RK-PROCESS-PROFILE.
           ACCEPT WS-INPUT-LINE FROM STANDARD-INPUT
           MOVE WS-INPUT-LINE(1:4) TO WS-LOOKUP-MCC
           OPEN INPUT MERCHANT-FILE
           IF WS-MERCH-STATUS NOT = '00'
               DISPLAY "RISK|ERROR|MERCH-FILE|" WS-MERCH-STATUS
               DISPLAY "RESULT|99"
               STOP RUN
           END-IF
           MOVE 'N' TO WS-EOF-MERCH
           MOVE 'N' TO WS-MERCH-FOUND
           PERFORM RK-PROFILE-SEARCH UNTIL WS-MERCH-EOF
           IF NOT WS-MERCH-LOCATED
               DISPLAY "RISK|PROFILE|NOT-FOUND|" WS-LOOKUP-MCC
           END-IF
           CLOSE MERCHANT-FILE
           DISPLAY "RESULT|00".
       RK-PROFILE-SEARCH.
           READ MERCHANT-FILE
               AT END SET WS-MERCH-EOF TO TRUE
               NOT AT END
                   IF MERCH-MCC-CODE = WS-LOOKUP-MCC
                       MOVE 'Y' TO WS-MERCH-FOUND
                       DISPLAY "RISK|PROFILE|" MERCH-ID "|"
                           MERCH-LEGAL-NAME "|"
                           "MCC=" MERCH-MCC-CODE "|"
                           "TIER=" MERCH-RISK-TIER "|"
                           "VOL=" MERCH-MONTHLY-VOL "|"
                           "STATUS=" MERCH-STATUS
                   END-IF
           END-READ.
      *> ── KMW 2008: Amount scoring — 4-level nested IF, NO END-IF.
      *> ELSE pairs with nearest IF. KMW's comment below is WRONG.
       RK-CHECK-AMOUNT.
           IF WS-INPUT-AMOUNT >= WS-SAR-THRESHOLD
               ADD 35 TO WS-RISK-SCORE
               IF WS-INPUT-MCC >= WS-MCC-GAMBLING-LOW
                   AND WS-INPUT-MCC <= WS-MCC-GAMBLING-HIGH
                   ADD 25 TO WS-RISK-SCORE
                   MOVE "SAR-AMOUNT+GAMBLING-MCC" TO WS-RISK-REASON
                   IF WS-INPUT-AMOUNT >= 10000
                       ADD 15 TO WS-RISK-SCORE
                       MOVE "SAR-OVER-10K+GAMBLING" TO WS-RISK-REASON
                       IF WS-INPUT-AMOUNT >= 25000
                           ADD 10 TO WS-RISK-SCORE
                           MOVE "EXTREME-AMOUNT+GAMBLING"
                               TO WS-RISK-REASON
           ELSE
      *>       KMW: "This ELSE matches the outermost IF." WRONG.
               IF WS-INPUT-AMOUNT >= WS-HIGH-AMOUNT
                   ADD 15 TO WS-RISK-SCORE
                   IF WS-INPUT-AMOUNT >= WS-MEDIUM-AMOUNT
                       ADD 5 TO WS-RISK-SCORE.
      *> ── MCC-based risk + conflicting tier scoring ─────────
       RK-CHECK-MCC.
           MOVE WS-INPUT-MCC TO WS-TIER-CLASS
           IF WS-INPUT-MCC >= WS-MCC-GAMBLING-LOW
               AND WS-INPUT-MCC <= WS-MCC-GAMBLING-HIGH
               ADD 20 TO WS-RISK-SCORE
               IF WS-RISK-REASON = SPACES
                   MOVE "GAMBLING-MCC" TO WS-RISK-REASON
               END-IF
           END-IF
           IF WS-INPUT-MCC >= WS-MCC-MONEY-SVC-LOW
               AND WS-INPUT-MCC <= WS-MCC-MONEY-SVC-HIGH
               ADD 15 TO WS-RISK-SCORE
               IF WS-RISK-REASON = SPACES
                   MOVE "MONEY-SERVICES-MCC" TO WS-RISK-REASON
               END-IF
           END-IF
      *>   KMW scores 4-5, then OFS ALSO scores 3-5. Tier 4 = 35 pts.
           PERFORM RK-TIER-SCORE-KMW
           PERFORM RK-TIER-SCORE-OFFSHORE.
       RK-TIER-SCORE-KMW.
           IF RK-HIGH-RISK
               ADD 25 TO WS-RISK-SCORE
               IF WS-RISK-REASON = SPACES
                   MOVE "HIGH-RISK-TIER" TO WS-RISK-REASON
               END-IF
           END-IF.
      *> OFS: "Basel II requires tier 3+." KMW: "Tier 3 is NOT high."
       RK-TIER-SCORE-OFFSHORE.
           MOVE WS-TIER-CLASS TO WS-TIER-LEVEL
           IF RK-RISKY
               ADD 10 TO WS-RISK-SCORE
           END-IF
           IF RK-CRITICAL
               ADD 15 TO WS-RISK-SCORE
           END-IF.
      *> ── KMW 2008: INSPECT TALLYING — keyword scanning.
      *> COBOL CONCEPT: INSPECT counts substring occurrences.
       RK-CHECK-KEYWORDS.
           MOVE 0 TO WS-CASH-TALLY WS-WIRE-TALLY WS-URGENT-TALLY
                      WS-OFFSHORE-TALLY WS-CRYPTO-TALLY
                      WS-SUSPICIOUS-WORDS
           INSPECT WS-INPUT-DESC TALLYING
               WS-CASH-TALLY FOR ALL "CASH"
           INSPECT WS-INPUT-DESC TALLYING
               WS-WIRE-TALLY FOR ALL "WIRE"
           INSPECT WS-INPUT-DESC TALLYING
               WS-URGENT-TALLY FOR ALL "URGENT"
           INSPECT WS-INPUT-DESC TALLYING
               WS-OFFSHORE-TALLY FOR ALL "OFFSHORE"
           INSPECT WS-INPUT-DESC TALLYING
               WS-CRYPTO-TALLY FOR ALL "CRYPTO"
           ADD WS-CASH-TALLY WS-WIRE-TALLY WS-URGENT-TALLY
               WS-OFFSHORE-TALLY WS-CRYPTO-TALLY
               TO WS-SUSPICIOUS-WORDS
           IF WS-SUSPICIOUS-WORDS > 0
               ADD 5 TO WS-RISK-SCORE
               IF WS-SUSPICIOUS-WORDS > 2
                   ADD 10 TO WS-RISK-SCORE
               END-IF
               IF WS-RISK-REASON = SPACES
                   MOVE "SUSPICIOUS-KEYWORDS" TO WS-RISK-REASON
               END-IF
           END-IF.
      *> ── KMW 2008: Velocity — PER HOUR. >5/hr = burst fraud. ──
      *>   MIDNIGHT BOUNDARY HAZARD: The "per-hour" check resets at
      *>   midnight. 10 transactions at 23:59 and 10 at 00:01 score
      *>   as two separate bursts of 10, not one burst of 20. A
      *>   structured attacker who splits activity across the midnight
      *>   boundary never triggers the hourly threshold.
      *>
      *>   EBCDIC SORT ORDER: The IF comparison on TRANS-ACCT-ID uses
      *>   character equality. On EBCDIC, lowercase letters sort BEFORE
      *>   uppercase ('a' < 'A' < '1'). On ASCII it's reversed ('1' <
      *>   'A' < 'a'). If account IDs ever contain mixed case, the
      *>   sequential scan will find different matches on z/OS vs
      *>   GnuCOBOL — a silent migration bug.
       RK-VELOCITY-CHECK.
           OPEN INPUT TRANSACTION-FILE
           IF WS-TRANS-STATUS NOT = '00'
               GO TO RK-VELOCITY-EXIT
           END-IF
           MOVE 0 TO WS-HOURLY-COUNT
           MOVE 'N' TO WS-EOF-TRANS
           PERFORM RK-VELOCITY-READ UNTIL WS-TRANS-EOF
           CLOSE TRANSACTION-FILE
           IF WS-HOURLY-COUNT > WS-HOURLY-THRESHOLD
               ADD 20 TO WS-RISK-SCORE
               IF WS-RISK-REASON = SPACES
                   MOVE "VELOCITY-HOURLY-EXCEEDED" TO WS-RISK-REASON
               END-IF
           END-IF.
       RK-VELOCITY-READ.
           READ TRANSACTION-FILE
               AT END SET WS-TRANS-EOF TO TRUE
               NOT AT END
                   IF TRANS-ACCT-ID = WS-INPUT-ACCT
                       MOVE TRANS-TIME(1:2) TO WS-TXN-HOUR
                       IF WS-TXN-HOUR = WS-CURRENT-HOUR
                           ADD 1 TO WS-HOURLY-COUNT
                       END-IF
                   END-IF
           END-READ.
       RK-VELOCITY-EXIT.
           EXIT.
      *> ── OFS 2009: Velocity V2 — PER DAY. >20/day.
      *> CONFLICT: Both this AND KMW's run. 35-45 pts combined. ──
       RK-VELOCITY-CHECK-V2.
           OPEN INPUT TRANSACTION-FILE
           IF WS-TRANS-STATUS NOT = '00'
               GO TO RK-VELOCITY-V2-EXIT
           END-IF
           MOVE 0 TO WS-DAILY-TXN-CTR
           MOVE 'N' TO WS-EOF-TRANS
           PERFORM RK-VELOCITY-V2-READ UNTIL WS-TRANS-EOF
           CLOSE TRANSACTION-FILE
           IF WS-DAILY-TXN-CTR > WS-DAILY-THRESHOLD
               ADD 15 TO WS-RISK-SCORE
               IF WS-RISK-REASON = SPACES
                   MOVE "VELOCITY-DAILY-EXCEEDED" TO WS-RISK-REASON
               END-IF
               IF WS-DAILY-TXN-CTR > 30
                   ADD 10 TO WS-RISK-SCORE
               END-IF
           END-IF.
       RK-VELOCITY-V2-READ.
           READ TRANSACTION-FILE
               AT END SET WS-TRANS-EOF TO TRUE
               NOT AT END
                   IF TRANS-ACCT-ID = WS-INPUT-ACCT
                       MOVE TRANS-DATE TO WS-TXN-DATE-CMP
                       IF WS-TXN-DATE-CMP = WS-CURRENT-DATE-8
                           ADD 1 TO WS-DAILY-TXN-CTR
                       END-IF
                   END-IF
           END-READ.
       RK-VELOCITY-V2-EXIT.
           EXIT.
      *> ── OFS 2009: ML Score. TODO: CICS call. Hardcodes 50.
      *> IF > 70 never fires. Production since 2009. Dead code. ──
       RK-ML-SCORE.
           MOVE 50 TO WS-ML-SCORE
           IF WS-ML-SCORE > 70
               ADD 20 TO WS-RISK-SCORE
               IF WS-ML-SCORE > 90
                   ADD 20 TO WS-RISK-SCORE
               END-IF
           END-IF.
      *> ── OFS 2011: "Replaces KMW's threshold check." REALITY:
      *> KMW's NOT removed. $9.5K = 35+30 = 65 pts from amount. ──
       RK-AMOUNT-VALIDATION-ROUTINE.
           EVALUATE TRUE
               WHEN WS-INPUT-AMOUNT >= 9500
                   ADD 30 TO WS-RISK-SCORE
               WHEN WS-INPUT-AMOUNT >= 5000
                   ADD 15 TO WS-RISK-SCORE
               WHEN WS-INPUT-AMOUNT >= 1000
                   ADD 5 TO WS-RISK-SCORE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.
      *> ── REGULATORY COMPLIANCE CONTEXT (FR-037) ──────────────
      *>   On a real banking system, this risk engine would feed into
      *>   three mandatory batch programs:
      *>
      *>   CTR (Currency Transaction Reports): Any customer with
      *>   same-day cash aggregate exceeding $10,000 triggers a CTR
      *>   filed with FinCEN within 15 days. Our WS-SAR-THRESHOLD
      *>   at $9,500 pre-flags near-limit activity.
      *>
      *>   SAR (Suspicious Activity Reports): Detect structuring
      *>   (multiple sub-$10K cash transactions by same customer),
      *>   velocity anomalies (20+ transactions/day), and round-
      *>   amount clustering ($9,900, $9,800 patterns). Must file
      *>   within 30 days of detection.
      *>
      *>   OFAC (SDN List Screening): Compare customer names and
      *>   account IDs against the Specially Designated Nationals
      *>   list. Exact match = auto-block. Fuzzy match (Soundex,
      *>   Levenshtein distance) score > 85 = manual review.
      *>
      *>   SWIFT message formats shape the data: MT103 (customer
      *>   transfers), MT202 (interbank), MT940 (statements).
      *>   ISO 20022 transition replaces these: MT103→pacs.008,
      *>   MT940→camt.053.
      *>
      *> ── Final risk evaluation ─────────────────────────────
       RK-EVALUATE-RISK.
           MOVE WS-INPUT-AMOUNT TO WS-DISPLAY-AMOUNT
           MOVE WS-RISK-SCORE TO WS-DISPLAY-SCORE
           IF WS-RISK-SCORE >= WS-RISK-THRESHOLD
               DISPLAY "RISK|FLAG|"
                   WS-INPUT-ACCT "|"
                   WS-DISPLAY-AMOUNT "|"
                   WS-DISPLAY-SCORE "|"
                   WS-RISK-REASON
           ELSE
               DISPLAY "RISK|PASS|"
                   WS-INPUT-ACCT "|"
                   WS-DISPLAY-AMOUNT "|"
                   WS-DISPLAY-SCORE
           END-IF.

      *> ── DEAD PARAGRAPHS ──────────────────────────────────────────
      *> These paragraphs are never PERFORMed, GO TO'd, or ALTERed.

      *> RK-DEAD-GEO-FENCE: Geolocation-based risk scoring.
      *> OFS 2009-07-14: "Phase 2 — geo-fencing. Score transactions
      *> originating >500km from cardholder's registered address."
      *> Required CICS real-time call to mapping service. CICS
      *> integration was never funded. WS-GEO-LATITUDE and
      *> WS-GEO-LONGITUDE (declared above) were added for this.
      *> Both have been 0.000000 since 2009.
       RK-DEAD-GEO-FENCE.
           IF WS-GEO-LATITUDE NOT = 0
               ADD 15 TO WS-RISK-SCORE
               MOVE "GEO-FENCE-VIOLATION" TO WS-RISK-REASON
           END-IF.
       RK-DEAD-GEO-FENCE-EXIT.
           EXIT.

      *> RK-DEAD-DEVICE-FINGERPRINT: Device identification for mobile.
      *> OFS 2011-04-20: "Mobile transactions need device fingerprinting.
      *> Hash the device ID against known devices for the account."
      *> Killed in the 2012-01-15 "final cleanup" review because
      *> the CICS team refused to build the device registry API.
      *> WS-DEAD-DEVICE-ID (declared above) was added for this.
       RK-DEAD-DEVICE-FINGERPRINT.
           IF WS-DEAD-DEVICE-ID NOT = SPACES
               INSPECT WS-DEAD-DEVICE-ID TALLYING
                   WS-SUSPICIOUS-WORDS FOR ALL "UNKNOWN"
           END-IF.
       RK-DEAD-DEVICE-FINGERPRINT-EXIT.
           EXIT.
