      *>================================================================*
      *>  EDUCATIONAL NOTE: This program contains INTENTIONAL anti-
      *>  patterns for teaching. See KNOWN_ISSUES.md for the catalog.
      *>================================================================*
      *>  Program:     DISPUTE.cob
      *>  System:      ENTERPRISE PAYROLL — Chargeback / Dispute Proc
      *>  Author:      ACS (Angela Chen-Stevenson, 1994)
      *>  Written:     1994-08-12 (IBM ES/9000 Model 900)
      *>  JCL:  //PAYRL500 JOB (ACCT),'DISPUTE PROC',CLASS=A
      *>        //STEP01   EXEC PGM=DISPUTE,PARM='FILE'
      *>        //DISPFILE DD DSN=PAYRL.DISPUTES.MASTER,DISP=SHR
      *>        //RPTFILE  DD DSN=PAYRL.DISPUTE.REPORT,DISP=(NEW,CATLG)
      *>  Change Log:
      *>    1994-08-12  ACS  Initial — FILE and LIST operations
      *>    1994-10-03  ACS  ADVANCE with ALTER-based state machine
      *>    1994-11-21  ACS  RESOLVE and reversal computation
      *>    1995-02-14  ACS  STRING/UNSTRING for reason codes
      *>    1995-06-30  ACS  Direct PERFORM path (skips CALC-REVERSAL)
      *>    1996-01-15  ACS  Started Report Writer rewrite (RD section)
      *>    1996-03-22  ACS  Last day. Transferred to CICS. RD abandoned.
      *>  WARNING: ALTER modifies GO TO targets AT RUNTIME. Two code
      *>  paths for ADVANCE — ALTER (correct) vs PERFORM (buggy).
      *>================================================================*

       IDENTIFICATION DIVISION.
       PROGRAM-ID. DISPUTE.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT DISPUTE-FILE ASSIGN TO "DISPUTES.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
      *>   ACS 1996: Report file — assigned but never opened
           SELECT REPORT-FILE ASSIGN TO "DISPRPT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-RPT.

       DATA DIVISION.
       FILE SECTION.
       FD  DISPUTE-FILE.
           COPY "DISPREC.cpy".
      *>  ACS 1996: Abandoned Report Writer FD
       FD  REPORT-FILE REPORT IS DISP-RPT.

       WORKING-STORAGE SECTION.
       01  WS-FS           PIC X(2).
       01  WS-FS-RPT       PIC X(2).
       01  WS-EOF-FLAG     PIC X(1) VALUE 'N'.
           88  WS-EOF      VALUE 'Y'.
           88  WS-NOT-EOF  VALUE 'N'.
       01  WS-CMD-OP       PIC X(10).
       01  WS-CMD-ARGS     PIC X(200).
       01  WS-ARG-ACCT     PIC X(10).
       01  WS-ARG-TXID     PIC X(12).
       01  WS-ARG-AMT      PIC S9(7)V99.
       01  WS-ARG-RSN      PIC X(4).
       01  WS-ARG-MERCH    PIC X(10).
       01  WS-ARG-DID      PIC X(12).
       01  WS-ARG-OUTCOME  PIC X(1).
       01  WS-DCTR         PIC 9(6) VALUE 0.
       01  WS-NEW-ID       PIC X(12).
       01  WS-DATE-NOW.
           05  WS-YYYY     PIC 9(4).
           05  WS-MM       PIC 9(2).
           05  WS-DD       PIC 9(2).
       01  WS-TODAY        PIC 9(8).
       01  WS-DEADLINE     PIC 9(8).
      *> 'N' = ALTER path (correct). 'Y' = direct (buggy).
       01  WS-USE-DIRECT   PIC X(1) VALUE 'N'.
           88  WS-ALTER-PATH  VALUE 'N'.
           88  WS-DIRECT-PATH VALUE 'Y'.
       01  WS-OLD-ST       PIC X(1).
       01  WS-RSN-NET      PIC X(4).
       01  WS-RSN-CAT      PIC X(20).
       01  WS-RSN-FULL     PIC X(60).
       01  WS-SPTR         PIC 9(3).
       01  WS-TALLY        PIC 9(3).
       01  WS-EV-SCORE     PIC 9(3) VALUE 0.
       01  WS-EV-B1        PIC X(1).
       01  WS-EV-B2        PIC X(1).
       01  WS-REV-PCT      PIC 9V99 VALUE 0.
       01  WS-REV-AMT      PIC S9(7)V99 COMP-3.
       01  WS-LST-T        PIC 9(5) VALUE 0.
       01  WS-LST-O        PIC 9(5) VALUE 0.
       01  WS-LST-C        PIC 9(5) VALUE 0.
       01  WS-RC           PIC X(2) VALUE '00'.
       01  WS-TBL-CNT      PIC 9(4) VALUE 0.
       01  WS-TBL.
           05  WS-REC PIC X(150) OCCURS 500 TIMES.
       01  WS-IX           PIC 9(4).
       01  WS-FND          PIC X(1) VALUE 'N'.
           88  WS-FOUND    VALUE 'Y'.
           88  WS-NOT-FOUND VALUE 'N'.

      *>  ACS 1996: Abandoned REPORT SECTION. Compiles, never used.
       REPORT SECTION.
       RD  DISP-RPT PAGE LIMIT 60 HEADING 1
           FIRST DETAIL 5 LAST DETAIL 55 FOOTING 58.
       01  RPT-HDR TYPE PAGE HEADING.
           05  LINE 1.
               10  COLUMN 1  PIC X(30) VALUE "DISPUTE SUMMARY".
               10  COLUMN 40 PIC Z(4)9 SOURCE PAGE-COUNTER.
       01  RPT-DTL TYPE DETAIL.
           05  LINE PLUS 1.
               10  COLUMN 1  PIC X(12) SOURCE DISP-ID.
               10  COLUMN 15 PIC X(1)  SOURCE DISP-STATE.
               10  COLUMN 22 PIC Z(5)9.99 SOURCE DISP-AMOUNT.

       PROCEDURE DIVISION.
       DP-MAIN.
           ACCEPT WS-CMD-OP FROM COMMAND-LINE
           INSPECT WS-CMD-OP CONVERTING "fileadvancresol"
               TO "FILEADVANCRESOL"
           PERFORM DP-INIT
           EVALUATE WS-CMD-OP(1:7)
               WHEN 'FILE   ' PERFORM DP-FILE-DISPUTE
               WHEN 'ADVANCE' PERFORM DP-ADVANCE-DISPUTE
               WHEN 'RESOLVE' PERFORM DP-RESOLVE-DISPUTE
               WHEN 'LIST   ' PERFORM DP-LIST-DISPUTES
               WHEN OTHER DISPLAY "ERROR|UNKNOWN-OP|" WS-CMD-OP
                   MOVE '03' TO WS-RC
           END-EVALUATE
           DISPLAY "RESULT|" WS-RC
           STOP RUN.
       DP-INIT.
           ACCEPT WS-DATE-NOW FROM DATE YYYYMMDD
           STRING WS-YYYY WS-MM WS-DD DELIMITED BY SIZE
               INTO WS-TODAY END-STRING
      *>   Deadline = filed + ~120 days. Faked by adding 4 months.
           MOVE WS-TODAY TO WS-DEADLINE
           ADD 400 TO WS-DEADLINE.
       DP-FILE-DISPUTE.
           ACCEPT WS-CMD-ARGS FROM ENVIRONMENT "DISPUTE_ARGS"
           MOVE 1 TO WS-SPTR  MOVE 0 TO WS-TALLY
           UNSTRING WS-CMD-ARGS DELIMITED BY '|'
               INTO WS-ARG-ACCT WS-ARG-TXID WS-ARG-AMT
                    WS-ARG-RSN WS-ARG-MERCH
               WITH POINTER WS-SPTR TALLYING WS-TALLY
           END-UNSTRING
           IF WS-TALLY < 5
               DISPLAY "ERROR|FILE|BAD-ARGS|" WS-TALLY
               MOVE '03' TO WS-RC  GO TO DP-FILE-X  END-IF
           ADD 1 TO WS-DCTR
           STRING "DSP-" WS-YYYY WS-MM "-" DELIMITED BY SIZE
               INTO WS-NEW-ID END-STRING
           MOVE WS-DCTR TO WS-NEW-ID(11:2)
           MOVE WS-NEW-ID TO DISP-ID  MOVE 'O' TO DISP-STATE
           MOVE WS-ARG-RSN TO DISP-REASON-CODE
           MOVE '00' TO DISP-EVIDENCE-FLAGS
           MOVE WS-ARG-AMT TO DISP-AMOUNT  MOVE 'U' TO DISP-LIABILITY
           MOVE WS-TODAY TO DISP-FILED-DATE  DISP-ORIG-TX-DATE
           MOVE WS-DEADLINE TO DISP-DEADLINE-DATE
           MOVE 0 TO DISP-RESOLVED-DATE  DISP-REVERSAL-AMOUNT
           MOVE WS-ARG-MERCH TO DISP-MERCH-ID
           MOVE WS-ARG-TXID TO DISP-ORIG-TX-ID
           MOVE WS-ARG-ACCT TO DISP-ORIG-ACCT-ID
           MOVE 'D' TO DISP-ORIG-TX-TYPE
           MOVE WS-ARG-AMT TO DISP-ORIG-TX-AMOUNT
           MOVE ZEROS TO DISP-ORIG-TX-TIME
           MOVE SPACES TO DISP-ORIG-TX-DESC DISP-ORIG-BATCH-ID
               DISP-FILLER DISP-REVERSAL-BANK DISP-REVERSAL-ACCT
           MOVE '00' TO DISP-ORIG-TX-STATUS DISP-REVERSAL-STATUS
           OPEN EXTEND DISPUTE-FILE
           IF WS-FS NOT = '00'  OPEN OUTPUT DISPUTE-FILE  END-IF
           WRITE DISPUTE-RECORD
           CLOSE DISPUTE-FILE
           DISPLAY "OK|FILE|" DISP-ID "|" DISP-STATE "|" DISP-AMOUNT
           MOVE '00' TO WS-RC.
       DP-FILE-X. EXIT.
      *>  ADVANCE: Two paths — ALTER (correct) vs PERFORM (buggy).
       DP-ADVANCE-DISPUTE.
           ACCEPT WS-CMD-ARGS FROM ENVIRONMENT "DISPUTE_ARGS"
           MOVE WS-CMD-ARGS(1:12) TO WS-ARG-DID
           PERFORM DP-LOAD-ALL
           SET WS-NOT-FOUND TO TRUE
           PERFORM VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-TBL-CNT OR WS-FOUND
               MOVE WS-REC(WS-IX) TO DISPUTE-RECORD
               IF DISP-ID = WS-ARG-DID SET WS-FOUND TO TRUE END-IF
           END-PERFORM
           IF WS-NOT-FOUND
               DISPLAY "ERROR|ADVANCE|NOT-FOUND|" WS-ARG-DID
               MOVE '03' TO WS-RC  GO TO DP-ADV-X  END-IF
           MOVE DISP-STATE TO WS-OLD-ST
      *>   ALTER PATH — calls DP-CALC-REVERSAL (correct)
           IF WS-ALTER-PATH
               EVALUATE TRUE
                   WHEN DISP-OPEN
                       ALTER DP-STATE-DISPATCH TO PROCEED TO
                           DP-HANDLE-REPRESENTED
                   WHEN DISP-REPRESENTED
                       ALTER DP-STATE-DISPATCH TO PROCEED TO
                           DP-HANDLE-PRE-ARB
                   WHEN DISP-PRE-ARB
                       DISPLAY "ERROR|ADVANCE|MUST-RESOLVE|"
                           WS-ARG-DID
                       MOVE '03' TO WS-RC  GO TO DP-ADV-X
                   WHEN DISP-CLOSED-WON OR DISP-CLOSED-LOST
                           OR DISP-WRITE-OFF
                       DISPLAY "ERROR|ADVANCE|CLOSED|" WS-ARG-DID
                       MOVE '03' TO WS-RC  GO TO DP-ADV-X
                   WHEN OTHER
                       MOVE '99' TO WS-RC  GO TO DP-ADV-X
               END-EVALUATE
               PERFORM DP-PARSE-REASON
               PERFORM DP-CHECK-EVIDENCE
               PERFORM DP-CALC-REVERSAL
               GO TO DP-STATE-DISPATCH
           ELSE
      *>       DIRECT PATH (buggy — skips DP-CALC-REVERSAL)
               EVALUATE TRUE
                   WHEN DISP-OPEN
                       PERFORM DP-HANDLE-REPRESENTED
                   WHEN DISP-REPRESENTED
                       PERFORM DP-HANDLE-PRE-ARB
                   WHEN OTHER
                       MOVE '99' TO WS-RC  GO TO DP-ADV-X
               END-EVALUATE
           END-IF
           MOVE DISPUTE-RECORD TO WS-REC(WS-IX)
           PERFORM DP-REWRITE-ALL
           DISPLAY "OK|ADVANCE|" DISP-ID "|" WS-OLD-ST "|" DISP-STATE
           MOVE '00' TO WS-RC.
       DP-ADV-X. EXIT.
      *>  ALTER TARGET. Default → DP-HANDLE-OPEN. Source tells you nothing.
       DP-STATE-DISPATCH.
           GO TO DP-HANDLE-OPEN.
       DP-HANDLE-OPEN.
           MOVE 'R' TO DISP-STATE  MOVE 'I' TO DISP-LIABILITY
           MOVE DISPUTE-RECORD TO WS-REC(WS-IX)
           PERFORM DP-REWRITE-ALL
           DISPLAY "OK|ADVANCE|" DISP-ID "|" WS-OLD-ST "|" DISP-STATE
           MOVE '00' TO WS-RC  GO TO DP-ADV-X.
       DP-HANDLE-REPRESENTED.
           MOVE 'P' TO DISP-STATE  MOVE 'M' TO DISP-LIABILITY
           MOVE DISPUTE-RECORD TO WS-REC(WS-IX)
           PERFORM DP-REWRITE-ALL
           DISPLAY "OK|ADVANCE|" DISP-ID "|" WS-OLD-ST "|" DISP-STATE
           MOVE '00' TO WS-RC  GO TO DP-ADV-X.
       DP-HANDLE-PRE-ARB.
           DISPLAY "ERROR|ADVANCE|PRE-ARB-TERMINAL|" DISP-ID
           MOVE '03' TO WS-RC  GO TO DP-ADV-X.
      *>  RESOLVE: 3-level nested EVALUATE — outcome x state x evidence.
       DP-RESOLVE-DISPUTE.
           ACCEPT WS-CMD-ARGS FROM ENVIRONMENT "DISPUTE_ARGS"
           MOVE 1 TO WS-SPTR  MOVE 0 TO WS-TALLY
           UNSTRING WS-CMD-ARGS DELIMITED BY '|'
               INTO WS-ARG-DID WS-ARG-OUTCOME
               WITH POINTER WS-SPTR TALLYING WS-TALLY
           END-UNSTRING
           IF WS-TALLY < 2
               DISPLAY "ERROR|RESOLVE|BAD-ARGS|" WS-TALLY
               MOVE '03' TO WS-RC  GO TO DP-RES-X  END-IF
           PERFORM DP-LOAD-ALL
           SET WS-NOT-FOUND TO TRUE
           PERFORM VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-TBL-CNT OR WS-FOUND
               MOVE WS-REC(WS-IX) TO DISPUTE-RECORD
               IF DISP-ID = WS-ARG-DID SET WS-FOUND TO TRUE END-IF
           END-PERFORM
           IF WS-NOT-FOUND
               DISPLAY "ERROR|RESOLVE|NOT-FOUND|" WS-ARG-DID
               MOVE '03' TO WS-RC  GO TO DP-RES-X  END-IF
           IF DISP-CLOSED-WON OR DISP-CLOSED-LOST OR DISP-WRITE-OFF
               DISPLAY "ERROR|RESOLVE|CLOSED|" WS-ARG-DID
               MOVE '03' TO WS-RC  GO TO DP-RES-X  END-IF
           EVALUATE TRUE
               WHEN WS-ARG-OUTCOME = 'W'
                   MOVE 'W' TO DISP-STATE  MOVE 'M' TO DISP-LIABILITY
                   PERFORM DP-PARSE-REASON  PERFORM DP-CHECK-EVIDENCE
                   EVALUATE TRUE
                       WHEN DISP-OPEN
                           MOVE 1.00 TO WS-REV-PCT
                       WHEN DISP-REPRESENTED
                           EVALUATE TRUE
                               WHEN WS-EV-SCORE > 75
                                   MOVE 1.00 TO WS-REV-PCT
                               WHEN WS-EV-SCORE > 50
                                   MOVE 0.75 TO WS-REV-PCT
                               WHEN OTHER
                                   MOVE 0.50 TO WS-REV-PCT
                                   MOVE 'S' TO DISP-LIABILITY
                           END-EVALUATE
                       WHEN DISP-PRE-ARB
                           EVALUATE TRUE
                               WHEN WS-EV-SCORE > 60
                                   MOVE 1.00 TO WS-REV-PCT
                               WHEN OTHER
                                   MOVE 0.80 TO WS-REV-PCT
                           END-EVALUATE
                       WHEN OTHER MOVE 1.00 TO WS-REV-PCT
                   END-EVALUATE
                   COMPUTE DISP-REVERSAL-AMOUNT ROUNDED =
                       DISP-AMOUNT * WS-REV-PCT
                   MOVE DISP-ORIG-ACCT-ID TO DISP-REVERSAL-ACCT
                   STRING "BANK_" DISP-ORIG-ACCT-ID(5:1)
                       DELIMITED BY SIZE INTO DISP-REVERSAL-BANK
                   END-STRING  MOVE '00' TO DISP-REVERSAL-STATUS
               WHEN WS-ARG-OUTCOME = 'L'
                   MOVE 'L' TO DISP-STATE  MOVE 'I' TO DISP-LIABILITY
                   MOVE 0 TO DISP-REVERSAL-AMOUNT
                   MOVE SPACES TO DISP-REVERSAL-BANK
                       DISP-REVERSAL-ACCT
                   MOVE '00' TO DISP-REVERSAL-STATUS
               WHEN WS-ARG-OUTCOME = 'X'
                   MOVE 'X' TO DISP-STATE  MOVE 'S' TO DISP-LIABILITY
                   COMPUTE DISP-REVERSAL-AMOUNT ROUNDED =
                       DISP-AMOUNT * 0.50
                   MOVE DISP-ORIG-ACCT-ID TO DISP-REVERSAL-ACCT
                   STRING "BANK_" DISP-ORIG-ACCT-ID(5:1)
                       DELIMITED BY SIZE INTO DISP-REVERSAL-BANK
                   END-STRING  MOVE '00' TO DISP-REVERSAL-STATUS
               WHEN OTHER
                   DISPLAY "ERROR|RESOLVE|BAD-OUTCOME|" WS-ARG-OUTCOME
                   MOVE '03' TO WS-RC  GO TO DP-RES-X
           END-EVALUATE
           MOVE WS-TODAY TO DISP-RESOLVED-DATE
           MOVE DISPUTE-RECORD TO WS-REC(WS-IX)
           PERFORM DP-REWRITE-ALL
           DISPLAY "OK|RESOLVE|" DISP-ID "|" WS-ARG-OUTCOME
               "|" DISP-REVERSAL-AMOUNT
           MOVE '00' TO WS-RC.
       DP-RES-X. EXIT.
       DP-LIST-DISPUTES.
           MOVE 0 TO WS-LST-T WS-LST-O WS-LST-C
           OPEN INPUT DISPUTE-FILE
           IF WS-FS NOT = '00'
               DISPLAY "ERROR|LIST|NO-FILE|" WS-FS
               MOVE '03' TO WS-RC  GO TO DP-LST-X  END-IF
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ DISPUTE-FILE AT END SET WS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-LST-T
                   IF DISP-OPEN OR DISP-REPRESENTED OR DISP-PRE-ARB
                       ADD 1 TO WS-LST-O
                   ELSE ADD 1 TO WS-LST-C END-IF
                   DISPLAY "DISP|" DISP-ID "|" DISP-STATE "|"
                       DISP-AMOUNT "|" DISP-REASON-CODE "|"
                       DISP-LIABILITY "|" DISP-REVERSAL-AMOUNT
               END-READ
           END-PERFORM
           CLOSE DISPUTE-FILE
           DISPLAY "LIST|TOTAL=" WS-LST-T "|OPEN=" WS-LST-O
               "|CLOSED=" WS-LST-C
           MOVE '00' TO WS-RC.
       DP-LST-X. EXIT.
      *>  Parse reason code via STRING/UNSTRING. Builds "4853-GOODS..."
      *>  then UNSTRINGs it apart "for the reporting module" (dead).
       DP-PARSE-REASON.
           MOVE DISP-REASON-CODE TO WS-RSN-NET
           MOVE SPACES TO WS-RSN-FULL  MOVE 1 TO WS-SPTR
           STRING WS-RSN-NET DELIMITED BY SPACE "-" DELIMITED BY SIZE
               INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
           EVALUATE WS-RSN-NET
               WHEN '4501' STRING "COUNTERFEIT" DELIMITED BY SIZE
                   INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
               WHEN '4837' STRING "NO-AUTH" DELIMITED BY SIZE
                   INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
               WHEN '4853' STRING "GOODS-NOT-RCVD" DELIMITED BY SIZE
                   INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
               WHEN '4860' STRING "CREDIT-NOT-PROC" DELIMITED BY SIZE
                   INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
               WHEN OTHER STRING "UNKNOWN" DELIMITED BY SIZE
                   INTO WS-RSN-FULL WITH POINTER WS-SPTR END-STRING
           END-EVALUATE
      *>   UNSTRING the thing we just built. "For reporting." (Dead.)
           MOVE 1 TO WS-SPTR
           UNSTRING WS-RSN-FULL DELIMITED BY '-'
               INTO WS-RSN-NET WS-RSN-CAT
               WITH POINTER WS-SPTR TALLYING WS-TALLY
           END-UNSTRING.
      *>  Evidence score: 3-level nested EVALUATE TRUE.
       DP-CHECK-EVIDENCE.
           MOVE 0 TO WS-EV-SCORE
           MOVE DISP-EVIDENCE-FLAGS(1:1) TO WS-EV-B1
           MOVE DISP-EVIDENCE-FLAGS(2:1) TO WS-EV-B2
           EVALUATE TRUE
               WHEN WS-EV-B1 = '1' OR '3' OR '5' OR '7'
                   ADD 30 TO WS-EV-SCORE
                   EVALUATE TRUE
                       WHEN WS-EV-B1 = '3' OR '7'
                           ADD 25 TO WS-EV-SCORE
                           EVALUATE TRUE
                               WHEN WS-EV-SCORE > 50
                                   ADD 10 TO WS-EV-SCORE
                               WHEN OTHER CONTINUE
                           END-EVALUATE
                       WHEN OTHER CONTINUE
                   END-EVALUATE
               WHEN WS-EV-B1 = '2' OR '6'
                   ADD 25 TO WS-EV-SCORE
               WHEN OTHER CONTINUE
           END-EVALUATE
           EVALUATE TRUE
               WHEN WS-EV-B2 = '1' OR '3'
                   ADD 20 TO WS-EV-SCORE
               WHEN WS-EV-B2 = '2'
                   ADD 15 TO WS-EV-SCORE
               WHEN OTHER CONTINUE
           END-EVALUATE.
      *>  Provisional reversal. ALTER path only. Direct path = BUG.
       DP-CALC-REVERSAL.
           MOVE 0 TO WS-REV-AMT
           IF WS-EV-SCORE > 60  MOVE 1.00 TO WS-REV-PCT
           ELSE IF WS-EV-SCORE > 30  MOVE 0.75 TO WS-REV-PCT
           ELSE MOVE 0.50 TO WS-REV-PCT  END-IF
           COMPUTE WS-REV-AMT ROUNDED = DISP-AMOUNT * WS-REV-PCT
           MOVE WS-REV-AMT TO DISP-REVERSAL-AMOUNT
           MOVE DISP-ORIG-ACCT-ID TO DISP-REVERSAL-ACCT
           STRING "BANK_" DISP-ORIG-ACCT-ID(5:1) DELIMITED BY SIZE
               INTO DISP-REVERSAL-BANK END-STRING
           MOVE '01' TO DISP-REVERSAL-STATUS.
      *>  Load entire file into OCCURS table / rewrite from table.
       DP-LOAD-ALL.
           MOVE 0 TO WS-TBL-CNT  SET WS-NOT-EOF TO TRUE
           OPEN INPUT DISPUTE-FILE
           IF WS-FS NOT = '00'
               MOVE '99' TO WS-RC  GO TO DP-LOAD-X  END-IF
           PERFORM UNTIL WS-EOF OR WS-TBL-CNT >= 500
               READ DISPUTE-FILE AT END SET WS-EOF TO TRUE
               NOT AT END ADD 1 TO WS-TBL-CNT
                   MOVE DISPUTE-RECORD TO WS-REC(WS-TBL-CNT)
               END-READ
           END-PERFORM
           CLOSE DISPUTE-FILE.
       DP-LOAD-X. EXIT.
       DP-REWRITE-ALL.
           OPEN OUTPUT DISPUTE-FILE
           IF WS-FS NOT = '00'
               MOVE '99' TO WS-RC  GO TO DP-RW-X  END-IF
           PERFORM VARYING WS-IX FROM 1 BY 1
               UNTIL WS-IX > WS-TBL-CNT
               MOVE WS-REC(WS-IX) TO DISPUTE-RECORD
               WRITE DISPUTE-RECORD
           END-PERFORM
           CLOSE DISPUTE-FILE.
       DP-RW-X. EXIT.
      *>  Dead Report Writer. Compiles. Never called. Since 1996-03-22.
       DP-DEAD-REPORT.
           OPEN OUTPUT REPORT-FILE  INITIATE DISP-RPT
           SET WS-NOT-EOF TO TRUE  OPEN INPUT DISPUTE-FILE
           PERFORM UNTIL WS-EOF
               READ DISPUTE-FILE AT END SET WS-EOF TO TRUE
                   NOT AT END GENERATE RPT-DTL
               END-READ
           END-PERFORM
           CLOSE DISPUTE-FILE  TERMINATE DISP-RPT
           CLOSE REPORT-FILE.
