# Enterprise Payroll Processor — Fictional History

**System**: ENTERPRISE PAYROLL PROCESSOR
**Original Platform**: IBM System/370 Model 158
**Current Platform**: IBM zSeries 900 (migrated 2002)
**Language**: COBOL-74 / COBOL-85 hybrid

---

## Origin Story (Fictional)

The Enterprise Payroll Processor was first written in March 1974 by **JRK** (initials only — full name lost to time) on an IBM System/370 at First National Insurance Corp. It processed payroll for 200 employees using punch cards for input and line printer for output.

### The Developers

| Initials | Era | Style | Contribution |
|----------|-----|-------|-------------|
| JRK | 1974-1978 | COBOL-68 purist | Original system. GO TO everything. ALTER for flow control. Cryptic names. |
| TKN | 1978-1981 | COBOL-68 + coupling | Merchant onboarding. GO TO DEPENDING ON, shared WORKING-STORAGE, COPY REPLACING. |
| PMR | 1983-1997 | COBOL-85 adopter | Tax engine. PERFORM THRU. Better names, but hardcoded values override copybook. |
| RBJ | 1986-1994 | SORT enthusiast | Fee engine. SORT INPUT/OUTPUT PROCEDURE, triple-nested PERFORM VARYING, "temporary" overrides. |
| SLW | 1991-1995 | Half-and-half | Benefits/deductions. Started structured, reverted to GO TO under pressure. |
| ACS | 1994-1996 | State machine artist | Dispute processor. ALTER-based state machine, dead Report Writer, STRING/UNSTRING. |
| Y2K Team | 1999-2002 | Corporate mandate | Date remediation. Parallel old/new fields. Excessive DISPLAY tracing. Half-finished refactor. |
| KMW + OFS | 2008-2012 | Contradicting fixes | Risk engine. Onshore/offshore duplicated velocity checks, amount scoring, tier definitions. |

### The Expansion: Payment Processing (1978-2012)

In 1978, First National decided the payroll batch system had spare capacity on the evening shift. Thomas Nguyen (TKN) was tasked with "adding merchant onboarding — just a few paragraphs." That became MERCHANT.cob. In 1986, Bobby Johnson (RBJ) bolted on fee calculation. In 1994, Angela Chen-Stevenson (ACS) added dispute processing ("just until the CICS team builds a real one"). In 2008, the risk engine was outsourced to an offshore team who duplicated what the onshore developer (KMW) had already built.

By 2012, a payroll mainframe was running a payment processor. Nobody planned it. Nobody approved it as an architecture. It grew organically, one "quick addition" at a time, across 34 years and 8 developers who never met each other.

### Why It Looks Like This

Every anti-pattern in this code exists because it was the correct decision at the time:

- **GO TO networks** (1974): COBOL-68 had no structured programming. GO TO was the only flow control besides PERFORM.
- **ALTER statements** (1974, 1994): Runtime flow modification was an "advanced technique." ACS repurposed it as a state machine — technically brilliant, practically unmaintainable.
- **GO TO DEPENDING ON** (1978): The COBOL-68 switch/case. TKN used it for operation dispatch and MCC routing.
- **PERFORM THRU** (1983): The COBOL-85 bridge — "call this range of paragraphs as one unit."
- **SORT INPUT/OUTPUT PROCEDURE** (1986): RBJ's coroutine-style batch processing. COBOL SORT hijacks program flow — you RELEASE records in, SORT sorts, you RETURN them out.
- **Nested IF without END-IF** (1978, 1983, 2008): Three different eras, same habit. END-IF existed after 1985 but old habits die hard.
- **Mixed COMP types** (1991): SLW used whatever USAGE felt right. The compiler handles conversions silently.
- **COPY REPLACING** (1981): TKN's proto-namespace to avoid field collisions. Text substitution, not semantic.
- **Dead code everywhere** (1993-2012): Dead Report Writer, dead ML placeholder, dead VIP override, dead garnishment. Removing code requires a change request, testing, and sign-off. It's easier to "disable" it.
- **Contradicting fixes** (2008-2012): Onshore and offshore teams independently wrote velocity checks, amount scoring, and tier definitions. Both run. Neither is correct alone.
- **"Temporary" overrides** (1989): RBJ's blended pricing was "just for Q2 1989." It's still active 37 years later.
- **Y2K artifacts** (2002): The remediation was done under extreme time pressure. "Add new fields, keep old fields, ship it."

### The Cardinal Rule

> "If it works in production, don't touch it." — Every COBOL maintainer, ever

This system processes 25 employees across 5 banks. In production, it would handle 50,000+ employees with the same code structure. The only difference would be the array sizes and the JCL resource allocations.

---

## Programs

### Payroll Subsystem (Original)

| Program | Lines | Era | Author | Purpose | Key Anti-Patterns |
|---------|-------|-----|--------|---------|-------------------|
| PAYROLL.cob | ~540 | 1974 | JRK | Main controller | GO TO network, ALTER (McCracken quote), magic numbers, dead paragraphs, period bug risk, numeric overflow, implied decimal traps, MOVE truncation, banker's rounding, 3270 terminal heritage, midnight hazards, input validation apathy, PERFORM THRU armed mine, FILE STATUS awareness |
| TAXCALC.cob | ~330 | 1983 | PMR | Tax computation | 6-level nested IF, PERFORM THRU armed mine, misleading comments, dead code, implied decimal zero-byte, banking day-count conventions, period bug risk |
| DEDUCTN.cob | ~380 | 1991 | SLW | Deductions | Structured/spaghetti hybrid, mixed COMP types, dead garnishment, dead FSA, period bug avoidance, MOVE CORRESPONDING drops, level 66 RENAMES |
| PAYBATCH.cob | ~430 | 2002 | Y2K | Batch output | Y2K dead code, Y2K windowing expiration, excessive DISPLAY tracing, batch ordering assumption, JCL/GDG heritage, EOD batch sequence, midnight/timezone hazards, FILE STATUS awareness, dialect migration notes |

### Payment Processing Subsystem (Bolted On)

| Program | Lines | Era | Author | Purpose | Key Anti-Patterns |
|---------|-------|-----|--------|---------|-------------------|
| MERCHANT.cob | ~510 | 1978 | TKN | Merchant onboarding & risk tiering | GO TO DEPENDING ON, shared WS coupling (WK-M4 triple reuse), COPY REPLACING, dead paragraphs, CICS vs batch WS persistence, DB2 DCLGEN heritage, EBCDIC sort order, REDEFINES guard gaps, 3270/BMS terminal heritage, TSB migration reference, group MOVE hazards, FILE STATUS awareness |
| FEEENGN.cob | ~510 | 1986 | RBJ | Fee calculation engine | SORT INPUT/OUTPUT PROCEDURE, 3-deep PERFORM VARYING, "temporary" blended pricing (37 years), contradicting rates, dead tier/refund paragraphs, SORT failure/IPL recovery, multi-currency ISO 4217, EBCDIC sort order, numeric overflow, implied decimal traps, batch ordering assumptions, FILE STATUS awareness |
| DISPUTE.cob | ~530 | 1994 | ACS | Chargeback lifecycle | ALTER state machine, dead Report Writer (RD), dead auto-escalate, STRING/UNSTRING parsing, dual advance paths, abend/recovery notes (S0C7/S0C4), CICS same-address-space risk, DB2/SQL heritage fields, FD implicit REDEFINES, input validation apathy |
| RISKCHK.cob | ~520 | 2008 | KMW+OFS | Pre-transaction risk scoring | Contradicting velocity checks, duplicate amount scoring, duplicate 88-levels (level 88 semantics), INSPECT TALLYING, dead ML/geo-fence/device paragraphs, midnight boundary reset, CTR/SAR/OFAC regulatory compliance, SWIFT/ISO 20022, numeric overflow (PIC 9(3) wrap), EBCDIC sort order, input validation apathy, batch ordering assumptions |

## Output Format

PAYBATCH produces pipe-delimited output compatible with the banking system's settlement format:

```
SOURCE_ACCT|DEST_ACCT|AMOUNT|Payroll deposit — Name|DAY
```

This feeds directly into the existing OUTBOUND.DAT → SETTLE.cob pipeline.

## See Also

- `KNOWN_ISSUES.md` — Detailed catalog of every anti-pattern (the educational crown jewel)
- `../KNOWN_ISSUES.md` — Banking system known issues (clean code issues)
