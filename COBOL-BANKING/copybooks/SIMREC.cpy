*> ================================================================
*> SIMREC.cpy — Simulation Working-Storage Variables
*> Used by: SIMULATE.cob, SETTLE.cob
*>
*> Provides working-storage for the hub-and-spoke inter-bank
*> settlement simulation. Includes pseudo-random seed generation,
*> transaction counters, and outbound record formatting.
*> ================================================================
*>
*> ═══════════════════════════════════════════════════════════
*> COBOL CONCEPT: Simulation Parameter Grouping
*> This copybook organizes simulation variables into logical
*> 01-level groups: parameters, counters, work areas, settlement
*> fields, and outbound parsing. Grouping related fields under
*> a single 01-level is a COBOL best practice — it documents
*> intent (these fields belong together) and makes it easy to
*> INITIALIZE an entire group to zeros/spaces in one statement.
*> ═══════════════════════════════════════════════════════════
*>
*> WS-SIM-PARAMS: Input parameters and pseudo-random seeds.
*> These are set once at program start from command-line args
*> and used throughout the simulation run.
 01  WS-SIM-PARAMS.
     05  WS-BANK-CODE        PIC X(8).
     05  WS-DAY-NUM          PIC 9(3).
     05  WS-DAY-NUM-STR      PIC X(5).
*>   Bank seed: a numeric value derived from the bank letter
*>   (A=1, B=2, ..., E=5). Used in pseudo-random calculations.
     05  WS-BANK-SEED        PIC 9(5).
     05  WS-NODE-LETTER      PIC X(1).
*>   Two seed fields for the deterministic pseudo-random generator.
*>   WS-SEED controls whether an account transacts today.
*>   WS-SEED2 controls the transaction type and amount.
     05  WS-SEED             PIC 9(5).
     05  WS-SEED2            PIC 9(5).
*>   Transaction sequence number — incremented per transaction
     05  WS-TX-SEQ           PIC 9(3) VALUE 0.

*> WS-SIM-COUNTERS: Running tallies of each transaction type.
*> These are accumulated during the run and displayed at the end.
 01  WS-SIM-COUNTERS.
     05  WS-SIM-DEPOSITS     PIC 9(5) VALUE 0.
     05  WS-SIM-WITHDRAWALS  PIC 9(5) VALUE 0.
     05  WS-SIM-TRANSFERS    PIC 9(5) VALUE 0.
     05  WS-SIM-OUTBOUND     PIC 9(5) VALUE 0.
     05  WS-SIM-FAILED       PIC 9(5) VALUE 0.
     05  WS-SIM-TOTAL        PIC 9(5) VALUE 0.

*> WS-SIM-WORK: Scratch fields used during transaction generation.
 01  WS-SIM-WORK.
     05  WS-SIM-AMOUNT       PIC S9(10)V99 VALUE 0.
     05  WS-SIM-RESULT       PIC X(2) VALUE '00'.
     05  WS-SIM-TYPE         PIC X(1) VALUE SPACES.
     05  WS-SIM-DESC         PIC X(40) VALUE SPACES.
     05  WS-TARGET-IDX       PIC 9(3) VALUE 0.
     05  WS-TARGET-BANK      PIC 9(1) VALUE 0.
     05  WS-TARGET-BANK-LTR  PIC X(1) VALUE SPACES.
     05  WS-TARGET-ACCT-NUM  PIC 9(1) VALUE 0.
     05  WS-OB-DEST-ID       PIC X(10) VALUE SPACES.
*>
*> ═══════════════════════════════════════════════════════════
*> COBOL CONCEPT: REDEFINES Clause
*> REDEFINES lets two field definitions occupy the same memory.
*> Below, WS-AMT-DISPLAY is PIC 9(8)V99 — a 10-byte numeric
*> field with an implied decimal between position 8 and 9.
*> WS-AMT-REDEF REDEFINES it, splitting the same 10 bytes into
*> WS-AMT-INT-PART (first 8 bytes) and WS-AMT-DEC-PART (last
*> 2 bytes). This lets us MOVE a numeric value into AMT-DISPLAY,
*> then read the integer and decimal portions separately as
*> strings — necessary for building pipe-delimited output where
*> we need an actual "." character between dollars and cents.
*> Think of it like a C union: same storage, different views.
*> ═══════════════════════════════════════════════════════════
*>
     05  WS-AMT-DISPLAY      PIC 9(8)V99.
     05  WS-AMT-REDEF REDEFINES WS-AMT-DISPLAY.
         10  WS-AMT-INT-PART PIC 9(8).
         10  WS-AMT-DEC-PART PIC 99.
     05  WS-AMT-STRING       PIC X(12).

*> WS-SETTLE-WORK: Fields used by SETTLE.cob for clearing house
*> settlement processing. Includes sequence numbers, volume
*> tracking, and nostro account lookup variables.
 01  WS-SETTLE-WORK.
     05  WS-STL-SEQ          PIC 9(5) VALUE 0.
     05  WS-STL-TOTAL-VOL    PIC S9(12)V99 VALUE 0.
     05  WS-STL-COUNT        PIC 9(5) VALUE 0.
     05  WS-STL-REJECTED     PIC 9(5) VALUE 0.
     05  WS-STL-SOURCE-LTR   PIC X(1).
     05  WS-STL-DEST-LTR     PIC X(1).
     05  WS-STL-NOSTRO-ID    PIC X(10).
     05  WS-STL-SRC-IDX      PIC 9(3).
     05  WS-STL-DST-IDX      PIC 9(3).
     05  WS-STL-AMOUNT       PIC S9(10)V99 VALUE 0.
     05  WS-STL-AMT-STR      PIC X(15).

*> WS-OB-PARSE: Fields for parsing pipe-delimited OUTBOUND.DAT
*> records. Each field receives one segment from UNSTRING.
 01  WS-OB-PARSE.
     05  WS-OBP-SOURCE       PIC X(10).
     05  WS-OBP-DEST         PIC X(10).
     05  WS-OBP-AMT-STR      PIC X(15).
     05  WS-OBP-DESC         PIC X(40).
     05  WS-OBP-DAY-STR      PIC X(5).
