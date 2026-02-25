*> ================================================================
*> COMCODE.cpy — Common Status Codes and Bank IDs
*> Shared across all COBOL programs and all 6 nodes
*> ================================================================
*>
*> ═══════════════════════════════════════════════════════════
*> COBOL CONCEPT: Shared Constants via Copybook
*> COBOL has no #define or const keyword. Instead, constants are
*> defined as 01-level groups in a copybook, where each field has
*> a VALUE clause. Every program that COPYs this file gets the
*> same set of named constants. This prevents magic numbers and
*> ensures all programs use identical status codes, bank IDs,
*> and type codes. If a new bank is added, you update this one
*> file and recompile everything.
*> ═══════════════════════════════════════════════════════════
*>
*> 01-level groups organize related constants together.
*> The 05-level items under each group share a logical category
*> but are independent fields — each with its own PIC and VALUE.
*>
*> RESULT-CODES: Used in TRANS-STATUS and DISPLAY "RESULT|XX"
 01  RESULT-CODES.
     05  RC-SUCCESS           PIC X(2) VALUE '00'.
     05  RC-NSF               PIC X(2) VALUE '01'.
     05  RC-LIMIT-EXCEEDED    PIC X(2) VALUE '02'.
     05  RC-INVALID-ACCT      PIC X(2) VALUE '03'.
     05  RC-ACCOUNT-FROZEN    PIC X(2) VALUE '04'.
     05  RC-FILE-ERROR        PIC X(2) VALUE '99'.

*> BANK-IDS: The 6 nodes in the system. PIC X(8) accommodates
*> the longest name ("CLEARING"). Shorter names are padded with
*> spaces on the right — standard COBOL alphanumeric behavior.
 01  BANK-IDS.
     05  BANK-FIRST-NATL      PIC X(8) VALUE 'BANK_A'.
     05  BANK-COMM-TRUST      PIC X(8) VALUE 'BANK_B'.
     05  BANK-PAC-SVGS        PIC X(8) VALUE 'BANK_C'.
     05  BANK-HRTG-FED        PIC X(8) VALUE 'BANK_D'.
     05  BANK-METRO-CU        PIC X(8) VALUE 'BANK_E'.
     05  BANK-CLEARING        PIC X(8) VALUE 'CLEARING'.

*> ACCOUNT-TYPES and ACCOUNT-STATUSES: Single-character codes
*> used throughout the system for filtering and validation.
 01  ACCOUNT-TYPES.
     05  ACCT-CHECKING        PIC X(1) VALUE 'C'.
     05  ACCT-SAVINGS         PIC X(1) VALUE 'S'.

 01  ACCOUNT-STATUSES.
     05  STATUS-ACTIVE        PIC X(1) VALUE 'A'.
     05  STATUS-CLOSED        PIC X(1) VALUE 'C'.
     05  STATUS-FROZEN        PIC X(1) VALUE 'F'.

*> TX-TYPES: Transaction type codes matching TRANSREC.cpy's
*> 88-level conditions. Having them here as named constants
*> allows programs to write: MOVE TX-DEPOSIT TO TRANS-TYPE
*> instead of the less readable: MOVE 'D' TO TRANS-TYPE
 01  TX-TYPES.
     05  TX-DEPOSIT           PIC X(1) VALUE 'D'.
     05  TX-WITHDRAW          PIC X(1) VALUE 'W'.
     05  TX-TRANSFER          PIC X(1) VALUE 'T'.
     05  TX-INTEREST          PIC X(1) VALUE 'I'.
     05  TX-FEE               PIC X(1) VALUE 'F'.
