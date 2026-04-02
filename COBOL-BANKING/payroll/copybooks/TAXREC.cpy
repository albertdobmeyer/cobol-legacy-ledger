*> ================================================================
*> TAXREC.cpy — Tax Bracket Table Layout
*> Used by: TAXCALC.cob, PAYROLL.cob
*> ================================================================
*>
*> COPYBOOK DEPENDENCY: Changing bracket field sizes here
*> requires recompiling BOTH programs. PMR once widened
*> TAX-BRACKET-MAX from S9(5) to S9(7) and forgot to
*> recompile PAYROLL.cob — gross pay computations used stale
*> offsets for two pay periods before anyone noticed.
*>
*> PMR 1983: "Brackets change every year. Put them in a table
*> so we only update the copybook, not the program."
*> Reality: The program ALSO has hardcoded brackets that
*> override these. See TAXCALC.cob KNOWN_ISSUES.
*>
*> JRK 1992: Added bracket 06 for new top rate. Never tested.
*> SLW 1995: "Don't touch this. It works. I think."
*>
 01  TAX-BRACKET-TABLE.
     05  TAX-BRACKET-ENTRY OCCURS 6 TIMES.
         10  TAX-BRACKET-MIN     PIC S9(7)V99 COMP-3.
         10  TAX-BRACKET-MAX     PIC S9(7)V99 COMP-3.
         10  TAX-BRACKET-RATE    PIC 9V9999.
*>           OVERPUNCH NOTE: TAX-BRACKET-RATE is DISPLAY format
*>           (no COMP). In EBCDIC, PIC S9(n) DISPLAY stores the
*>           sign as an overpunch on the last digit: +0 → '{',
*>           +1 → 'A', -1 → 'J'. Since TAX-BRACKET-RATE is
*>           unsigned (no S), overpunch does not apply — but if
*>           anyone adds an S, the rate "0.2200" would display
*>           as "0.220{" in a hex dump. Bewildering if you don't
*>           know the encoding.
*>
*>           BANKING STANDARD: Interest/tax rates should use
*>           PIC 9(3)V9(6) COMP-3 — six decimal places for
*>           precision (e.g., 005.250000 = 5.25%). Our 9V9999
*>           only has four decimal places, losing precision on
*>           rates like 7.6500% vs 7.65%.
         10  TAX-BRACKET-LABEL   PIC X(15).
*>           PMR: "Six brackets cover all income levels." Reality:
*>           Bracket 6 ceiling is 9999999.99 — any salary above
*>           $10M silently misclassifies. "All income levels" is
*>           only true if your employees aren't hedge fund managers.

*> PMR: Working fields for tax computation
 01  TAX-WORK-FIELDS.
     05  TAX-GROSS-PAY           PIC S9(7)V99 COMP-3.
     05  TAX-FED-AMOUNT          PIC S9(7)V99 COMP-3.
     05  TAX-STATE-AMOUNT        PIC S9(7)V99 COMP-3.
     05  TAX-FICA-AMOUNT         PIC S9(7)V99 COMP-3.
     05  TAX-TOTAL-AMOUNT        PIC S9(7)V99 COMP-3.
     05  TAX-NET-PAY             PIC S9(7)V99 COMP-3.
     05  TAX-WORK-RATE           PIC 9V9999.
     05  TAX-WORK-BASE           PIC S9(7)V99 COMP-3.
*>   JRK 1992: Temp field for "new algorithm". Never used.
     05  TAX-WORK-TEMP           PIC S9(9)V99 COMP-3.
     05  TAX-ERROR-FLAG          PIC X(1).
         88  TAX-OK              VALUE 'N'.
         88  TAX-ERROR           VALUE 'Y'.
