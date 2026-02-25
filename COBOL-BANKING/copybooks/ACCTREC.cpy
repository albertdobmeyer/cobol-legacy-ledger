*> ================================================================
*> ACCTREC.cpy — Account Record Layout (70 bytes total)
*> Used by: ACCOUNTS.cob, TRANSACT.cob, REPORTS.cob, VALIDATE.cob,
*>          INTEREST.cob, FEES.cob, RECONCILE.cob, SIMULATE.cob,
*>          SETTLE.cob
*> ================================================================
*>
*> ═══════════════════════════════════════════════════════════
*> COBOL CONCEPT: What is a Copybook?
*> A copybook is COBOL's version of a header file (#include in C,
*> import in Python). The COPY statement inserts this file's text
*> into the program at compile time. Every program that reads or
*> writes ACCOUNTS.DAT uses this same record layout, guaranteeing
*> they all agree on the exact byte positions of each field.
*> If you change a field here, all programs pick up the change
*> automatically on the next compile.
*> ═══════════════════════════════════════════════════════════
*>
*> Field-by-field breakdown with byte offsets:
*>   Bytes 1-10:   ACCT-ID         — Account identifier (text)
*>   Bytes 11-40:  ACCT-NAME       — Account holder name (text)
*>   Byte  41:     ACCT-TYPE       — 'C' checking or 'S' savings
*>   Bytes 42-53:  ACCT-BALANCE    — Signed amount with 2 decimals
*>   Byte  54:     ACCT-STATUS     — 'A' active, 'C' closed, 'F' frozen
*>   Bytes 55-62:  ACCT-OPEN-DATE  — YYYYMMDD when account opened
*>   Bytes 63-70:  ACCT-LAST-ACTIVITY — YYYYMMDD of last transaction
*>
 01  ACCOUNT-RECORD.
*>   PIC X(10) — ten alphanumeric characters (X = any character).
*>   Used for identifiers, names, codes — anything that is text.
     05  ACCT-ID              PIC X(10).
     05  ACCT-NAME            PIC X(30).
*>   PIC X(1) — a single character flag. The 88-level entries below
*>   define named conditions: IF ACCT-CHECKING is the same as
*>   IF ACCT-TYPE = 'C'. This makes code more readable.
     05  ACCT-TYPE            PIC X(1).
         88  ACCT-CHECKING    VALUE 'C'.
         88  ACCT-SAVINGS     VALUE 'S'.
*>   PIC S9(10)V99 — a signed numeric field.
*>     S = signed (can be negative, needed for balances)
*>     9(10) = up to 10 integer digits
*>     V = implied decimal point (not stored as a "." character)
*>     99 = 2 decimal places (cents)
*>   Total storage: 12 bytes. The V does not take a byte — it just
*>   tells COBOL where the decimal is during arithmetic.
     05  ACCT-BALANCE         PIC S9(10)V99.
     05  ACCT-STATUS          PIC X(1).
         88  ACCT-ACTIVE      VALUE 'A'.
         88  ACCT-CLOSED      VALUE 'C'.
         88  ACCT-FROZEN      VALUE 'F'.
*>   PIC 9(8) — eight unsigned numeric digits, no decimal.
*>   Used for dates in YYYYMMDD format (e.g., 20260224).
*>   Unlike PIC X, PIC 9 fields support arithmetic operations.
     05  ACCT-OPEN-DATE       PIC 9(8).
     05  ACCT-LAST-ACTIVITY   PIC 9(8).
