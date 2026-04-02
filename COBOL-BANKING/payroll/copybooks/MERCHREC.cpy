*> ================================================================
*> MERCHREC.cpy — Merchant Record Layout (120 bytes, LINE SEQUENTIAL)
*> Used by: MERCHANT.cob, FEEENGN.cob, RISKCHK.cob
*> ================================================================
*>
*> COPYBOOK DEPENDENCY WARNING: 3 programs include this file.
*> TKN once added 2 bytes to MERCH-LEGAL-NAME and forgot to
*> recompile FEEENGN.cob — it read the MCC code from what was
*> now the last 4 bytes of the name field. Fee calculations
*> ran against merchant names instead of MCC codes for a week.
*>
*> TKN 1978: Original layout for First National's merchant
*> onboarding system. Extended by RBJ (1986) for fee tiers and
*> by ACS (1994) for dispute tracking fields.
*>
*> MAINFRAME vs. DEMO:
*>   On the mainframe this was VSAM KSDS keyed on MERCH-ID.
*>   Here we use LINE SEQUENTIAL for demo simplicity.
*>   Real merchants would be in DB2, not flat files.
*>
*> REDEFINES CONCEPT: Two different views of the same bytes.
*>   Individual merchants have a DBA name and SSN.
*>   Aggregate merchants have a parent chain ID and unit count.
*>   The MERCH-TYPE field (byte 76) tells you which view to use.
*>   If you read the wrong REDEFINES, you get garbage.
*>
*> WARNING: RBJ added FEE-TIER-CODE at byte 85 in 1986 without
*> updating the byte offset comments. All offsets after byte 84
*> in the original TKN documentation are wrong.
*>
*> Layout (120 bytes total):
*>   Bytes 01-10:  MERCH-ID           PIC X(10)
*>   Bytes 11-40:  MERCH-LEGAL-NAME   PIC X(30)
*>   Bytes 41-44:  MERCH-MCC-CODE     PIC 9(4)
*>   Bytes 45-45:  MERCH-RISK-TIER    PIC 9(1)     [1=low..5=high]
*>   Bytes 46-50:  MERCH-RESERVE-PCT  PIC 9V9999
*>   Bytes 51-58:  MERCH-SPONSOR-BANK PIC X(8)
*>   Bytes 59-66:  MERCH-ONBOARD-DATE PIC 9(8)     [YYYYMMDD]
*>   Byte  67:     MERCH-STATUS       PIC X(1)
*>   Bytes 68-75:  MERCH-DBA-NAME / MERCH-CHAIN-ID  (REDEFINES)
*>   Byte  76:     MERCH-TYPE         PIC X(1)
*>   Bytes 77-84:  MERCH-VOLUME-LIMIT PIC S9(7)V99
*>   Byte  85:     MERCH-FEE-TIER     PIC 9(1)     [RBJ 1986]
*>   Bytes 86-92:  MERCH-MONTHLY-VOL  PIC S9(5)V99
*>   Bytes 93-120: MERCH-FILLER       PIC X(28)
*>
 01  MERCHANT-RECORD.
     05  MERCH-ID                PIC X(10).
     05  MERCH-LEGAL-NAME        PIC X(30).
*>   TKN: MCC = Merchant Category Code (ISO 18245)
*>   4-digit code classifying business type. 5411 = grocery,
*>   5812 = restaurant, 7995 = gambling. Risk scoring uses
*>   MCC to determine fraud probability.
     05  MERCH-MCC-CODE          PIC 9(4).
     05  MERCH-RISK-TIER         PIC 9(1).
         88  MERCH-LOW-RISK      VALUE 1.
         88  MERCH-MED-RISK      VALUE 2 THRU 3.
         88  MERCH-HIGH-RISK     VALUE 4 THRU 5.
     05  MERCH-RESERVE-PCT       PIC 9V9999.
     05  MERCH-SPONSOR-BANK      PIC X(8).
     05  MERCH-ONBOARD-DATE      PIC 9(8).
     05  MERCH-STATUS            PIC X(1).
         88  MERCH-ACTIVE        VALUE 'A'.
         88  MERCH-SUSPENDED     VALUE 'S'.
         88  MERCH-TERMINATED    VALUE 'T'.
         88  MERCH-PENDING       VALUE 'P'.
*>   REDEFINES: Individual vs Aggregate merchant views.
*>   TKN: "Type I = individual (sole prop/LLC), A = aggregate
*>   (chain/franchise). Use MERCH-TYPE to decide which to read."
*>   WARNING: If MERCH-TYPE is wrong, you read garbage.
*>
*>   REDEFINES SAFETY (S0C7 RISK): REDEFINES is COBOL's version
*>   of a C union with NO discriminator enforcement. Reading
*>   MERCH-AGGREGATE-DATA when the record is type 'I' performs
*>   arithmetic on character data in MERCH-UNIT-COUNT (PIC 9(3)
*>   overlaying bytes from MERCH-DBA-NAME). On IBM z/OS this
*>   triggers S0C7 (data exception) — the #1 most common COBOL
*>   abend. GnuCOBOL may produce garbage silently instead.
*>   The correct pattern: guard every REDEFINES access with an
*>   88-level check (IF MERCH-TYPE-AGGR before touching aggregate
*>   fields). MERCHANT.cob omits this guard in MR-072 (RETIER).
*>
*>   MEMORY ALIGNMENT: MERCH-VOLUME-LIMIT PIC S9(7)V99 is DISPLAY
*>   format here (9 bytes, no alignment needed). In WORKING-STORAGE
*>   computation fields, the COMP-3 equivalent would be 5 bytes.
*>   On z/OS, COMP (binary) fields crossing halfword boundaries
*>   cause performance penalties — the SYNCHRONIZED clause fixes
*>   this but inserts invisible slack bytes that change LRECL.
     05  MERCH-INDIVIDUAL-DATA.
         10  MERCH-DBA-NAME      PIC X(8).
     05  MERCH-AGGREGATE-DATA REDEFINES MERCH-INDIVIDUAL-DATA.
         10  MERCH-CHAIN-ID      PIC X(5).
         10  MERCH-UNIT-COUNT    PIC 9(3).
     05  MERCH-TYPE              PIC X(1).
         88  MERCH-TYPE-INDIV    VALUE 'I'.
         88  MERCH-TYPE-AGGR     VALUE 'A'.
*>   RBJ 1986: "Added volume limit and fee tier. TKN didn't
*>   think about pricing when he designed this."
     05  MERCH-VOLUME-LIMIT      PIC S9(7)V99.
     05  MERCH-FEE-TIER          PIC 9(1).
         88  MERCH-TIER-STARTUP  VALUE 1.
         88  MERCH-TIER-STANDARD VALUE 2.
         88  MERCH-TIER-PREMIUM  VALUE 3.
         88  MERCH-TIER-ENTERPRISE VALUE 4.
     05  MERCH-MONTHLY-VOL       PIC S9(5)V99.
*>   ACS 1994: "28 bytes reserved for dispute tracking fields —
*>   dispute count, last dispute date, chargeback ratio."
*>   CONTRADICTS: Disputes are stored in DISPREC.cpy as separate
*>   records. These 28 bytes have never been populated. ACS either
*>   forgot about this reservation or changed the design without
*>   updating MERCHREC. The bytes remain as dead filler.
     05  MERCH-FILLER             PIC X(28).
