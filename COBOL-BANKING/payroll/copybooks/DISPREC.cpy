*> ================================================================
*> DISPREC.cpy — Dispute / Chargeback Record Layout (150 bytes)
*> Used by: DISPUTE.cob
*> ================================================================
*>
*> ACS 1994: "Chargeback lifecycle tracking. Each dispute moves
*> through states: OPEN → REPRESENTED → PRE-ARB → CLOSED or
*> WRITE-OFF. The state machine is in DISPUTE.cob (via ALTER)."
*>
*> STATE MACHINE via ALTER: DISPUTE.cob uses ALTER to modify
*> GO TO targets based on dispute state. Each state transition
*> ALTERs the dispatch paragraph to jump to the next handler.
*> This is how state machines were built before EVALUATE.
*>
*> NESTED COPY CONCEPT: This copybook COPYs TRANSREC.cpy to
*> embed the original transaction record inside the dispute.
*> This creates a 103-byte sub-record within the 150-byte
*> dispute record. If TRANSREC.cpy changes, DISPREC.cpy
*> automatically picks up the change (which may break things).
*>
*> Layout (150 bytes total):
*>   Bytes 01-12:   DISP-ID             PIC X(12)
*>   Byte  13:      DISP-STATE          PIC X(1)
*>   Bytes 14-17:   DISP-REASON-CODE    PIC X(4)
*>   Bytes 18-19:   DISP-EVIDENCE-FLAGS PIC X(2)
*>   Bytes 20-28:   DISP-AMOUNT         PIC S9(7)V99
*>   Bytes 29-36:   DISP-FILED-DATE     PIC 9(8)
*>   Bytes 37-44:   DISP-DEADLINE-DATE  PIC 9(8)
*>   Bytes 45-52:   DISP-RESOLVED-DATE  PIC 9(8)
*>   Byte  53:      DISP-LIABILITY      PIC X(1)
*>   Bytes 54-63:   DISP-MERCH-ID       PIC X(10)
*>   Bytes 64-150:  DISP-ORIG-TX        (embedded transaction)
*>
 01  DISPUTE-RECORD.
     05  DISP-ID                 PIC X(12).
     05  DISP-STATE              PIC X(1).
         88  DISP-OPEN           VALUE 'O'.
         88  DISP-REPRESENTED    VALUE 'R'.
         88  DISP-PRE-ARB        VALUE 'P'.
         88  DISP-CLOSED-WON     VALUE 'W'.
         88  DISP-CLOSED-LOST    VALUE 'L'.
         88  DISP-WRITE-OFF      VALUE 'X'.
*>   ACS: Network reason codes (Visa/MC format).
*>   4501 = counterfeit, 4837 = no cardholder auth,
*>   4853 = goods not received, 4860 = credit not processed.
     05  DISP-REASON-CODE        PIC X(4).
*>   Evidence bitmap: bit 1 = receipt, bit 2 = signature,
*>   bit 3 = tracking number, bit 4 = communication log.
*>   ACS: "Should have been 88-levels but I was in a hurry."
     05  DISP-EVIDENCE-FLAGS     PIC X(2).
     05  DISP-AMOUNT             PIC S9(7)V99.
     05  DISP-FILED-DATE         PIC 9(8).
     05  DISP-DEADLINE-DATE      PIC 9(8).
     05  DISP-RESOLVED-DATE      PIC 9(8).
     05  DISP-LIABILITY          PIC X(1).
         88  DISP-ISSUER-LIABLE  VALUE 'I'.
         88  DISP-MERCH-LIABLE   VALUE 'M'.
         88  DISP-SPLIT-LIABLE   VALUE 'S'.
         88  DISP-UNDETERMINED   VALUE 'U'.
     05  DISP-MERCH-ID           PIC X(10).
*>   ACS: Embed original transaction for reference.
*>   This is a COPY of the 103-byte TRANSREC layout, nested
*>   inside this 150-byte dispute record. Any field name from
*>   TRANSREC.cpy is accessible as DISP-ORIG-TX.field-name
*>   (qualified reference).
     05  DISP-ORIG-TX.
         10  DISP-ORIG-TX-ID     PIC X(12).
         10  DISP-ORIG-ACCT-ID   PIC X(10).
         10  DISP-ORIG-TX-TYPE   PIC X(1).
         10  DISP-ORIG-TX-AMOUNT PIC S9(10)V99.
         10  DISP-ORIG-TX-DATE   PIC 9(8).
         10  DISP-ORIG-TX-TIME   PIC 9(6).
         10  DISP-ORIG-TX-DESC   PIC X(40).
         10  DISP-ORIG-TX-STATUS PIC X(2).
         10  DISP-ORIG-BATCH-ID  PIC X(12).
*>   Remaining filler to 150 bytes
     05  DISP-FILLER             PIC X(4).

*> ACS: Working fields for dispute processing
 01  DISP-WORK-FIELDS.
     05  DISP-WORK-STATE        PIC X(1).
     05  DISP-WORK-AMOUNT       PIC S9(7)V99 COMP-3.
     05  DISP-WORK-DAYS         PIC S9(4) COMP.
     05  DISP-WORK-FLAG         PIC X(1).
     05  DISP-COUNTER           PIC S9(4) COMP.
     05  DISP-ERROR-FLAG        PIC X(1).
         88  DISP-OK             VALUE 'N'.
         88  DISP-HAS-ERROR      VALUE 'Y'.

*> ACS: Dispute outcome tracking (for settlement reversal)
 01  DISP-SETTLEMENT-FIELDS.
     05  DISP-REVERSAL-AMOUNT   PIC S9(7)V99 COMP-3.
     05  DISP-REVERSAL-BANK     PIC X(8).
     05  DISP-REVERSAL-ACCT     PIC X(10).
     05  DISP-REVERSAL-STATUS   PIC X(2).
