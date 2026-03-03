*> ================================================================
*> FEEREC.cpy — Fee Schedule & Interchange Rate Layout
*> Used by: FEEENGN.cob
*> ================================================================
*>
*> RBJ 1986: "Fee calculation needs three tables: interchange
*> rates by card network, markup tiers by merchant volume,
*> and cross-border uplift factors. I put them all in one
*> copybook because compile time."
*>
*> OCCURS CONCEPT: COBOL arrays. OCCURS 4 TIMES creates an
*> array of 4 elements, indexed 1-4 (not 0-3!). Each element
*> is a group with sub-fields. Access via subscript:
*>   INTERCHANGE-RATE(2) = rate for network 2.
*>
*> COMP-3 CONCEPT: All rate fields use COMP-3 (packed decimal)
*> for precision. Financial rates like 0.0175 (1.75%) must not
*> lose precision to floating-point rounding.
*>
*> WARNING: RBJ's "temporary" blended pricing override from
*> 1989 is still active. FEEENGN.cob checks FEE-BLEND-FLAG
*> and bypasses the entire interchange table when 'Y'.
*> It has been 'Y' since 1989.
*>
 01  FEE-INTERCHANGE-TABLE.
*>   Network 1=Visa, 2=MasterCard, 3=Amex, 4=Discover
*>   These rates are from 1986. They are hilariously wrong
*>   for 2026, but FEEENGN.cob uses them anyway.
     05  FEE-INTERCHANGE-ENTRY OCCURS 4 TIMES.
         10  FEE-NETWORK-CODE    PIC X(4).
         10  FEE-NETWORK-NAME    PIC X(12).
         10  FEE-BASE-RATE       PIC S9V9999 COMP-3.
         10  FEE-PER-TX-CENTS    PIC S9(3) COMP.
         10  FEE-PREMIUM-RATE    PIC S9V9999 COMP-3.

 01  FEE-MARKUP-TIERS.
*>   RBJ: "Markup basis points by merchant monthly volume.
*>   Tier 1 = <$10K, Tier 2 = $10K-$100K, Tier 3 = $100K+."
*>   ACS 1994: Added Tier 4 for >$1M but never populated it.
     05  FEE-TIER-ENTRY OCCURS 4 TIMES.
         10  FEE-TIER-MIN-VOL    PIC S9(7)V99 COMP-3.
         10  FEE-TIER-MAX-VOL    PIC S9(7)V99 COMP-3.
         10  FEE-TIER-BPS        PIC S9(4) COMP.
         10  FEE-TIER-LABEL      PIC X(10).

 01  FEE-CROSS-BORDER.
*>   RBJ: "Cross-border uplift — 1% for international, 0% domestic."
*>   Offshore team 2008: Added FX spread field, never used.
     05  FEE-INTL-UPLIFT-PCT    PIC S9V9999 COMP-3.
     05  FEE-FX-SPREAD-PCT      PIC S9V9999 COMP-3.
     05  FEE-DOMESTIC-FLAG      PIC X(1).
         88  FEE-IS-DOMESTIC     VALUE 'D'.
         88  FEE-IS-INTL         VALUE 'I'.

 01  FEE-WORK-FIELDS.
     05  FEE-CALC-INTERCHANGE   PIC S9(7)V99 COMP-3.
     05  FEE-CALC-MARKUP        PIC S9(7)V99 COMP-3.
     05  FEE-CALC-CROSS-BORDER  PIC S9(7)V99 COMP-3.
     05  FEE-CALC-TOTAL         PIC S9(7)V99 COMP-3.
     05  FEE-TX-COUNT           PIC S9(7) COMP.
     05  FEE-ERROR-FLAG         PIC X(1).
         88  FEE-OK              VALUE 'N'.
         88  FEE-ERROR           VALUE 'Y'.

 01  FEE-BLEND-OVERRIDE.
*>   RBJ 1989: "Temporary blended pricing — flat 2.9% + $0.30
*>   per transaction. Will remove when interchange+ is ready."
*>   It's 2026. It's still 'Y'.
     05  FEE-BLEND-FLAG         PIC X(1) VALUE 'Y'.
     05  FEE-BLEND-RATE         PIC S9V9999 COMP-3 VALUE 0.0290.
     05  FEE-BLEND-PER-TX       PIC S9(3) COMP VALUE 30.
