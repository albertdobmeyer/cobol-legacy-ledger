*> ================================================================
*> PAYREC.cpy — Pay Stub Output Record Layout
*> Used by: PAYROLL.cob, PAYBATCH.cob
*> ================================================================
*>
*> COPYBOOK DEPENDENCY: Both PAYROLL.cob and PAYBATCH.cob write
*> pay stub records using this layout. Add a field here and you
*> must update BOTH writers — miss one and the output file
*> contains mixed-format records that silently corrupt downstream
*> processing.
*>
*> Y2K team 2002: "Cleaned up" the output record. Added
*> date fields with proper 4-digit years. Left the old
*> 2-digit year field in place "for backwards compatibility"
*> (nothing reads it anymore).
*>
 01  PAY-STUB-RECORD.
     05  PAY-EMP-ID              PIC X(7).
     05  PAY-EMP-NAME            PIC X(25).
     05  PAY-PERIOD-NUM          PIC 9(4).
     05  PAY-GROSS               PIC S9(7)V99 COMP-3.
     05  PAY-FED-TAX             PIC S9(7)V99 COMP-3.
     05  PAY-STATE-TAX           PIC S9(7)V99 COMP-3.
     05  PAY-FICA               PIC S9(7)V99 COMP-3.
     05  PAY-MEDICAL             PIC S9(5)V99 COMP-3.
     05  PAY-DENTAL              PIC S9(5)V99 COMP-3.
     05  PAY-401K                PIC S9(5)V99 COMP-3.
     05  PAY-NET                 PIC S9(7)V99 COMP-3.
     05  PAY-DEST-BANK           PIC X(8).
     05  PAY-DEST-ACCT           PIC X(10).
     05  PAY-DATE-FULL           PIC 9(8).
*>   Dead field — kept "for compatibility" per Y2K team.
*>   Y2K: "Remove after regression testing, target Q3 2002."
*>   It is now 2026. The field survives because removing it
*>   changes the record length from N to N-2 bytes, which
*>   would break any downstream program or JCL SORT that
*>   hardcodes LRECL. Easier to leave 2 dead bytes forever.
     05  PAY-DATE-YY             PIC 9(2).
