*> ================================================================
*> EMPREC.cpy — Employee Record Layout (95 bytes, LINE SEQUENTIAL)
*> Used by: PAYROLL.cob, TAXCALC.cob, DEDUCTN.cob, PAYBATCH.cob
*>
*> COPYBOOK DEPENDENCY WARNING: Changing ANY field's PIC clause in
*> this copybook forces recompilation of ALL four programs above.
*> Miss one and you get silent field misalignment — the program
*> still runs, it just reads bytes 51-59 as a name instead of a
*> salary. No error, no warning, just wrong numbers on paychecks.
*> A study of a worldwide car-leasing COBOL system found over 70%
*> of business rules existed only in the code — not in any
*> documentation. This copybook IS the documentation.
*> ================================================================
*>
*> LEGACY NOTE (JRK, 1974): Original layout designed for IBM 3270
*> terminal screen width. Extended in 1991 by SLW for benefits.
*>
*> MAINFRAME vs. DEMO:
*>   On a real IBM mainframe, salary/rate fields would use COMP-3
*>   (packed decimal) and hours/counters would use COMP (binary)
*>   for System/390 throughput optimization. Here we use DISPLAY
*>   format for LINE SEQUENTIAL file compatibility, but the mixed
*>   COMP types appear in WORKING-STORAGE computation fields
*>   throughout the programs — which is where the real anti-pattern
*>   lives (implicit type conversions on every COMPUTE).
*>
*> COMP-3 CONCEPT: Packed decimal — 2 digits per byte + sign nibble.
*>   PIC S9(7)V99 COMP-3 = 5 bytes. IBM AP/SP/MP/DP instructions
*>   operate directly on packed decimal without conversion.
*>
*> COMP CONCEPT: Binary — PIC S9(4) COMP = 2-byte halfword.
*>   Range -32768 to +32767. Faster for integer comparisons.
*>
*> ── NUMERIC STORAGE FORMAT COMPARISON (FR-028) ──────────────
*> The same value "+12345" stored three ways:
*>
*>   DISPLAY  PIC S9(5):     5 bytes  F1 F2 F3 F4 C5
*>     One EBCDIC char per digit. Sign overpunched on last byte:
*>     +12345 → C5 (positive), -12345 → D5 (negative).
*>     Displays as "1234E" (+) or "1234N" (-) in raw hex dumps.
*>
*>   COMP     PIC S9(5):     4 bytes  00 00 30 39
*>     Binary. Size by digit count:
*>       S9(1)-S9(4)  → 2 bytes (halfword)
*>       S9(5)-S9(9)  → 4 bytes (fullword)
*>       S9(10)-S9(18)→ 8 bytes (doubleword)
*>     TRUNC compiler option matters: TRUNC(STD) truncates to
*>     PIC digits (S9(4) max 9999); TRUNC(BIN) uses full binary
*>     range (halfword holds 0-65535, not 0-9999).
*>
*>   COMP-3   PIC S9(5):     3 bytes  12 34 5C
*>     Packed decimal: 2 digits per byte + sign nibble.
*>     C=positive, D=negative, F=unsigned.
*>     -12345 → 12 34 5D.  IBM z-series has native BCD
*>     instructions (AP/SP/MP/DP) making COMP-3 ~7-10x faster
*>     than binary for decimal arithmetic. COMP-3 is
*>     byte-identical between IBM and GnuCOBOL — the critical
*>     win for financial data interchange. COMP-1/COMP-2
*>     (floating point) is completely incompatible: IBM uses
*>     hex float, GnuCOBOL uses IEEE 754.
*>
*> ── OVERPUNCH SIGN ENCODING (FR-004) ───────────────────────
*> Signed DISPLAY fields (PIC S9(n)) encode the sign in the
*> zone nibble of the LAST byte:
*>
*>   EBCDIC positive: 0={  1=A  2=B  3=C  4=D  5=E  6=F  7=G  8=H  9=I
*>   EBCDIC negative: 0=}  1=J  2=K  3=L  4=M  5=N  6=O  7=P  8=Q  9=R
*>   ASCII Micro Focus: negatives use 0x70 zone (p q r s t u v w x y)
*>
*> A simple char-for-char EBCDIC↔ASCII translation CORRUPTS
*> signed numeric fields. Python parsers must handle overpunch
*> explicitly or every negative salary becomes garbage.
*>
*> WARNING: Do NOT change field order. JCL job PAYRL210 depends
*> on byte offsets for SORT FIELDS. See JCL member PAYRL210 in
*> SYS1.PROCLIB (if you can find it).
*>
*> Layout (95 bytes total):
*>   Bytes 01-07:  EMP-ID            PIC X(7)
*>   Bytes 08-32:  EMP-NAME          PIC X(25)
*>   Bytes 33-40:  EMP-BANK-CODE     PIC X(8)
*>   Bytes 41-50:  EMP-ACCT-ID       PIC X(10)
*>   Bytes 51-59:  EMP-SALARY        PIC S9(7)V99  (DISPLAY, 9 bytes)
*>   Bytes 60-64:  EMP-HOURLY-RATE   PIC S9(3)V99  (DISPLAY, 5 bytes)
*>   Bytes 65-68:  EMP-HOURS-WORKED  PIC S9(4)     (DISPLAY, 4 bytes)
*>   Bytes 69-72:  EMP-PAY-PERIODS   PIC S9(4)     (DISPLAY, 4 bytes)
*>   Byte  73:     EMP-STATUS        PIC X(1)
*>   Byte  74:     EMP-PAY-TYPE      PIC X(1)
*>   Bytes 75-76:  EMP-TAX-BRACKET   PIC 9(2)
*>   Bytes 77-84:  EMP-HIRE-DATE     PIC 9(8)
*>   Bytes 85-88:  EMP-DEPT-CODE     PIC X(4)
*>   Byte  89:     EMP-MEDICAL-PLAN  PIC X(1)
*>   Byte  90:     EMP-DENTAL-FLAG   PIC X(1)
*>   Bytes 91-93:  EMP-401K-PCT      PIC 9V99
*>   Bytes 94-95:  EMP-FILLER        PIC X(2)
*>
 01  EMPLOYEE-RECORD.
     05  EMP-ID                  PIC X(7).
     05  EMP-NAME                PIC X(25).
     05  EMP-BANK-CODE           PIC X(8).
     05  EMP-ACCT-ID             PIC X(10).
*>   DISPLAY format for file I/O. On a mainframe these would be
*>   COMP-3 packed decimal for throughput — see WORKING-STORAGE
*>   fields in each program for the COMP-3 computation pattern.
*>   MEMORY ALIGNMENT NOTE: On IBM z/OS, COMP fields must fall on
*>   halfword (2-byte) or fullword (4-byte) boundaries for hardware
*>   efficiency. COMP-3 has no alignment requirement (byte-addressed).
*>   The SYNCHRONIZED clause forces boundary alignment but inserts
*>   slack bytes that change the record length — a copybook change
*>   that silently breaks every program using a different version.
*>
*>   SLW 1991: "Salary is the annual amount, divided by PAY-PERIODS
*>   in PAYROLL.cob to get per-period gross."
*>   CONTRADICTS: PAYROLL.cob P-040 uses EMP-SALARY directly as the
*>   period amount for salaried employees (no division). If SLW's
*>   comment were true, every salaried employee would be overpaid
*>   by a factor of 26. The comment is wrong; the code is right.
     05  EMP-SALARY              PIC S9(7)V99.
     05  EMP-HOURLY-RATE         PIC S9(3)V99.
     05  EMP-HOURS-WORKED        PIC S9(4).
     05  EMP-PAY-PERIODS         PIC S9(4).
     05  EMP-STATUS              PIC X(1).
         88  EMP-ACTIVE          VALUE 'A'.
         88  EMP-TERMINATED      VALUE 'T'.
         88  EMP-ON-LEAVE        VALUE 'L'.
     05  EMP-PAY-TYPE            PIC X(1).
         88  EMP-SALARIED        VALUE 'S'.
         88  EMP-HOURLY          VALUE 'H'.
     05  EMP-TAX-BRACKET         PIC 9(2).
     05  EMP-HIRE-DATE           PIC 9(8).
     05  EMP-DEPT-CODE           PIC X(4).
*>   SLW 1991: Added deduction fields. Should have been a
*>   separate copybook but "we were in a hurry" (per SLW).
     05  EMP-MEDICAL-PLAN        PIC X(1).
         88  EMP-MED-NONE        VALUE 'N'.
         88  EMP-MED-BASIC       VALUE 'B'.
         88  EMP-MED-PREMIUM     VALUE 'P'.
     05  EMP-DENTAL-FLAG         PIC X(1).
         88  EMP-HAS-DENTAL      VALUE 'Y'.
         88  EMP-NO-DENTAL       VALUE 'N'.
     05  EMP-401K-PCT            PIC 9V99.
     05  EMP-FILLER              PIC X(2).
