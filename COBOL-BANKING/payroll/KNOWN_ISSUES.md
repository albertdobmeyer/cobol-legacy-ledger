# Payroll System Known Issues — Anti-Pattern Catalog

**System**: Enterprise Payroll Processor (Legacy Sidecar)
**Purpose**: Educational reference — every anti-pattern is intentional and documented
**Last Updated**: 2026-02-28

> **For instructors and students**: This document is the **answer key** for Lesson 9 of the Teaching Guide. The anti-patterns cataloged here are real-world patterns drawn from decades of mainframe COBOL development. They are **intentional and contained** to the payroll sidecar — all other COBOL in this project follows clean, modern practices. Each issue is cross-referenced to the specific source file and line where it occurs. Use this catalog alongside the analysis tools (Lesson 10) to verify your findings programmatically.

This document is the **educational crown jewel** of the payroll sidecar. Each issue catalogs a real-world COBOL anti-pattern, explains why it exists, and describes what a modern developer would do instead.

---

## PAYROLL.cob Issues

### PY-01: GO TO Network (Paragraph Spaghetti)

**What**: P-000 through P-090 form an interconnected GO TO network. Flow control jumps between paragraphs non-sequentially (P-070 → P-010, P-040 → P-050, etc.).

**Era**: 1974 (JRK). COBOL-68 had no EVALUATE, no inline PERFORM, limited END-IF.

**Why It Exists**: GO TO was the only way to implement loops and conditional branches. The PERFORM statement existed but was limited to calling single paragraphs without parameters.

**Risk**: Adding a new paragraph between existing ones can break the flow chain. There is no compiler warning when a GO TO target is deleted.

**Modern Equivalent**: PERFORM UNTIL loops, EVALUATE/WHEN, structured IF/END-IF.

---

### PY-02: ALTER Statement (Runtime GO TO Modification)

**What**: `ALTER P-030 TO PROCEED TO P-040` changes where `GO TO` in P-030 will jump — at runtime. The same GO TO statement can go to different paragraphs depending on previous execution.

**Era**: 1974 (JRK). ALTER was an "advanced technique" in IBM training courses.

**Why It Exists**: Before EVALUATE (added in COBOL-85), ALTER was the standard way to implement computed dispatch — "go to this paragraph if salaried, that paragraph if hourly."

**Risk**: Extremely difficult to trace execution flow. Static analysis tools cannot determine GO TO targets without simulating ALTER chains. The COBOL-85 standard deprecated ALTER, and COBOL-2002 removed it entirely.

**Modern Equivalent**: EVALUATE TRUE / WHEN condition / PERFORM paragraph.

---

### PY-03: Cryptic Paragraph and Variable Names

**What**: Paragraphs named P-010, P-020, etc. Variables named WK-A1, WK-B2, WK-M1, WK-M3.

**Era**: 1974 (JRK). Common IBM mainframe convention.

**Why It Exists**: Early COBOL had a 30-character name limit. Paragraph numbering (P-010, P-020 by tens) left room to insert new paragraphs (P-015) without renaming. Variable prefixes (WK = working) saved characters.

**Risk**: New developers cannot understand the code without extensive tribal knowledge or documentation (which rarely exists).

**Modern Equivalent**: Descriptive names — PROCESS-SALARIED-PAY, COMPUTE-OVERTIME, EMPLOYEE-HOURLY-RATE.

---

### PY-04: Magic Numbers

**What**: WK-M1 = 40 (standard work hours), WK-M2 = 1.50 (overtime multiplier), WK-M3 = 80 (overtime cap). No comments, no named constants.

**Era**: 1974 (JRK). Named constants via 01-level VALUE clauses were available but not universally adopted.

**Why It Exists**: JRK used numeric literals for "obvious" values. Overtime rules were mandated by law and "everyone knows 40 hours and time-and-a-half."

**Risk**: When overtime rules change, you must find every magic number in every program. Searching for "40" returns hundreds of false positives.

**Modern Equivalent**: Named constants in a shared copybook (like PAYCOM.cpy, which PMR added later).

---

### PY-05: Dead Paragraph (P-085)

**What**: P-085 (overtime cap check) is never PERFORMed or GO TO'd. It was replaced when SLW restructured P-045 in 1991 but never deleted.

**Era**: 1991 (SLW removed the call, left the paragraph).

**Why It Exists**: Removing code from a production COBOL program requires a formal change request, regression testing, and sign-off. It is universally considered "safer" to leave dead code in place than to risk breaking something by removing it.

**Risk**: Dead code misleads readers into thinking it is executed. It also accumulates, making the program harder to understand over time.

**Modern Equivalent**: Version control. Delete the code; git preserves the history.

---

## TAXCALC.cob Issues

### TX-01: 6-Level Nested IF Without END-IF

**What**: COMPUTE-FEDERAL contains 6 nested IF statements with no END-IF terminators. A single period (`.`) at the end terminates all 6 levels simultaneously.

**Era**: 1983 (PMR). COBOL-68 had no END-IF; COBOL-85 added it, but PMR used the old style.

**Why It Exists**: PMR learned COBOL-68 and carried the habits to COBOL-85. The nested IF worked correctly and was never refactored. "If it ain't broke, don't fix it."

**Risk**: Adding a statement inside the nesting changes which IF each ELSE matches. A misplaced period terminates ALL open scopes. These bugs are nearly invisible in code review.

**Modern Equivalent**: EVALUATE TRUE / WHEN condition / statement / END-EVALUATE.

---

### TX-02: PERFORM THRU (Paragraph Range Execution)

**What**: `PERFORM COMPUTE-FEDERAL THRU COMPUTE-FICA-EXIT` executes all paragraphs from COMPUTE-FEDERAL through COMPUTE-FICA-EXIT in sequence, including any paragraphs between them.

**Era**: 1983 (PMR). PERFORM THRU was considered "standard practice."

**Why It Exists**: Before inline PERFORM (COBOL-85), THRU was the way to group related operations. The problem is that inserting a new paragraph between the start and end of the range silently adds it to the execution.

**Risk**: If someone adds a paragraph between COMPUTE-FEDERAL and COMPUTE-FICA-EXIT, it will execute as part of the tax calculation without any explicit call. Compiler gives no warning.

**Modern Equivalent**: PERFORM individual paragraphs or use inline PERFORM blocks.

---

### TX-03: Misleading Comments (5% vs 7.25%)

**What**: Comments throughout say "5% state tax rate." The actual code uses `WS-DEFAULT-STATE-RATE` which is `0.0725` (7.25%). PAYCOM.cpy also has `PAYCOM-STATE-RATE VALUE 0.0500` (5%) — but TAXCALC ignores it.

**Era**: 1983 (PMR wrote "5%"), 1992 (JRK changed rate to 7.25% without updating comments).

**Why It Exists**: Comments are not verified by the compiler. When the rate changed, JRK updated the code but not the comments. This is the single most common documentation bug in legacy COBOL.

**Risk**: New developers trust comments over code. A developer "fixing" the rate to match the comments would introduce a 2.25% tax calculation error.

**Modern Equivalent**: Use named constants whose names describe the value. `STATE-TAX-RATE-7-25-PCT` is self-documenting.

---

### TX-04: Hardcoded Brackets Override Copybook

**What**: WS-HARDCODED-BRACKETS duplicates the tax bracket table from TAXREC.cpy with different values. The program uses the hardcoded version, never the copybook.

**Era**: 1983 (PMR). "Just in case the copybook isn't loaded correctly."

**Why It Exists**: PMR didn't trust the COPY mechanism. The hardcoded values were "verified" and the copybook values were "from someone else."

**Risk**: Updating TAXREC.cpy has no effect on tax calculations. Two sources of truth = zero sources of truth.

**Modern Equivalent**: Single source of truth. Use the copybook or don't — never both.

---

### TX-05: Dead Marginal Rate Code

**What**: COMPUTE-MARGINAL paragraph implements a partial marginal tax rate algorithm that is never called.

**Era**: 1992 (JRK). "TODO — finish later." Never finished.

**Why It Exists**: JRK planned to replace the flat-per-bracket approach with proper marginal rates. Management said "the current one works fine." The half-implemented code was left in place.

**Risk**: A future developer might call this paragraph thinking it works. It doesn't.

---

### TX-06: Outdated FICA Wage Base

**What**: PAYCOM-FICA-LIMIT is $160,200 (the 1997 Social Security wage base). The 2026 limit is much higher.

**Era**: 1997 (PMR's last update).

**Why It Exists**: PMR updated the limit in 1997 and retired in 1998. Nobody knew the limit needed annual updating.

---

## DEDUCTN.cob Issues

### DD-01: Structured Top / Spaghetti Bottom

**What**: The top half of the program uses clean PERFORM loops (MAIN-PARA → PROCESS-EMPLOYEE → COMPUTE-*). The bottom half (DEDUCTION-OVERFLOW-HANDLER) uses GO TO to jump back into the processing loop.

**Era**: 1991 (SLW). The structured part was written during normal development. The GO TO part was a 2 AM production fix.

**Why It Exists**: When production breaks at 2 AM, you fix the immediate problem as fast as possible. Structured refactoring happens "later" (it never does). This hybrid pattern is the most common real-world COBOL style.

**Risk**: The GO TO bypasses the normal return path of PROCESS-EMPLOYEE. If any logic is added after the PERFORM COMPUTE-* calls, it won't execute for overflow cases.

---

### DD-02: Mixed COMP Types

**What**: Medical uses COMP-3, dental uses COMP, 401(k) uses DISPLAY. All three are added together, requiring implicit type conversion.

**Era**: 1991 (SLW). Three different "preferences" for three different fields.

**Why It Exists**: COBOL allows mixing COMP types in arithmetic. The compiler inserts conversion instructions silently. SLW used whatever felt natural for each field.

**Risk**: Performance degradation from implicit conversions. On mainframes with millions of records, this matters. For 25 employees, nobody notices.

**Modern Equivalent**: Consistent USAGE clause across all numeric fields in a group.

---

### DD-03: Contradicting Comments from 3 Developers

**What**: The 401(k) section has comments from SLW ("50% match"), PMR ("4% match cap"), and JRK (nothing — left the field undocumented). The code uses 50% of employee contribution (SLW's version).

**Era**: 1991-1993. Three developers, three interpretations, one codebase.

**Why It Exists**: Each developer documented their understanding without checking existing comments. Nobody reconciled the contradictions.

---

### DD-04: Dead Garnishment Code

**What**: DEAD-GARNISHMENT paragraph computes wage garnishments using PAYCOM-GARN-PCT (set to 0.00 since 1993).

**Era**: 1991 (SLW added), 1993 (PMR "disabled").

**Why It Exists**: The garnishment feature was moved to a new system. Instead of deleting the code, PMR zeroed out the constants and set the flag to 'N'. The code still executes but produces 0.

---

### DD-05: Wrong Medical Division Factor

**What**: Medical deduction divides annual cost by 12 (monthly) instead of 26 (biweekly pay periods).

**Era**: 1991 (SLW). "Divide annual by 12 for monthly, close enough."

**Why It Exists**: SLW confused "monthly cost" with "per-pay-period cost." The result is that employees are under-deducted by about 54% for medical premiums.

**Risk**: Actual financial discrepancy — the company absorbs the difference.

---

## PAYBATCH.cob Issues

### PB-01: Y2K Dead Date Conversion Code

**What**: Y2K-REVERSE-CONVERT paragraph converts 2-digit years to 4-digit using a windowing technique. It is never called.

**Era**: 2002 (Y2K team). Added "just in case" there were 2-digit dates in input. There aren't.

**Why It Exists**: The Y2K team added defensive code for every possible date format they could imagine. This one handles a case that doesn't exist in the input data.

**Risk**: The Y2K pivot year (50) means this code will break again in 2050 if anyone ever calls it.

---

### PB-02: Excessive DISPLAY Tracing

**What**: WS-TRACE-FLAG defaults to 'Y', producing DISPLAY output for every employee read, skip, and write. In a 25-employee run, this generates 100+ trace lines that nobody reads.

**Era**: 2002 (Y2K team). "For validation during Y2K testing."

**Why It Exists**: The Y2K team needed to verify date conversions were correct. They added tracing and forgot to remove it (or set the default to 'N').

**Risk**: Performance impact on large batches. Log files fill up. Signal-to-noise ratio approaches zero.

**Modern Equivalent**: Configurable log levels (DEBUG, INFO, WARN, ERROR).

---

### PB-03: Half-Finished Format Refactor

**What**: Outbound file is pipe-delimited (new format). Report output is still fixed-width (old format). Two formatting systems in one program.

**Era**: 2002 (Y2K team). Started converting all output to pipe-delimited, gave up halfway.

**Why It Exists**: The downstream settlement system accepted pipe-delimited. The downstream report parser expected fixed-width. Converting the report parser was out of scope for Y2K. "We'll do it in Phase 2." Phase 2 never happened.

---

### PB-04: Temporary Flat Tax Rate

**What**: PAYBATCH uses a hardcoded 30% flat tax rate instead of calling TAXCALC. Comments say "temporary."

**Era**: 2002 (Y2K team). "We don't have time to integrate TAXCALC here."

**Why It Exists**: Tight Y2K deadline. Integrating TAXCALC properly required testing the PERFORM THRU interface. The Y2K team chose a flat estimate and moved on.

**Risk**: Batch output amounts don't match actual payroll amounts. The outbound settlement records have incorrect net pay values.

---

## PAYCOM.cpy Issues

### PC-01: Conflicting Daily Limits

**What**: WK-B2 = 500,000 and PAYCOM-DAILY-LIMIT = 750,000. Both claim to be "max daily payroll batch." PAYROLL.cob uses WK-B2. DEDUCTN.cob uses PAYCOM-DAILY-LIMIT.

**Era**: 1974 (JRK: WK-B2) and 1991 (SLW: PAYCOM-DAILY-LIMIT).

**Why It Exists**: SLW added PAYCOM-DAILY-LIMIT without checking for WK-B2. JRK's cryptic naming made it invisible.

---

### PC-02: Comment/Value Mismatch (Medical Premium)

**What**: Comment says "$250/month per employee." VALUE is 275.00.

**Era**: 1991 (SLW). Rate was $250 when written, updated to $275 later without fixing the comment.

---

### PC-03: Dead Garnishment Constants

**What**: PAYCOM-DEAD-SECTION contains three garnishment-related constants, all zeroed out since 1993.

**Era**: 1988 (added), 1993 (zeroed).

---

## EMPREC.cpy Issues

### ER-01: Mixed COMP Types in One Record

**What**: Salary uses COMP-3, hours use COMP, text fields use DISPLAY. Three different storage formats in one 120-byte record.

**Era**: 1974 (COMP-3), 1983 (COMP), 1991 (DISPLAY added for new fields).

**Why It Exists**: Each developer used the storage format they were comfortable with. The compiler handles all conversions but inserts hidden overhead.

---

### ER-02: Undocumented Byte Offsets

**What**: JCL job PAYRL210 (SORT) depends on exact byte offsets. Changing field order or sizes breaks the sort job without any compile error.

**Era**: 1974 (JRK). JCL SORT fields reference byte positions, not field names.

**Why It Exists**: JCL and COBOL are separate systems. JCL doesn't read copybooks — it uses raw byte offsets. This creates an invisible coupling.

---

## MERCHANT.cob Issues

### MR-01: GO TO DEPENDING ON (Computed Branch)

**What**: MR-000 dispatches operations (ONBOARD, LOOKUP, RETIER, LIST) via `GO TO MR-020 MR-060 MR-070 MR-080 DEPENDING ON WK-M1`. A second `GO TO DEPENDING ON` in MR-040 routes MCC code ranges to different risk-tier paragraphs.

**Era**: 1978 (TKN). COBOL-68 had no EVALUATE statement.

**Why It Exists**: GO TO DEPENDING ON was the standard COBOL-68 equivalent of a switch/case statement. TKN used it because it was the only computed branch available.

**Risk**: Adding a new operation requires updating the numeric mapping AND the DEPENDING ON target list in the exact same order. Off-by-one errors are invisible at compile time.

**Modern Equivalent**: EVALUATE TRUE / WHEN condition / PERFORM paragraph.

---

### MR-02: Shared WORKING-STORAGE Coupling

**What**: WK-M1 through WK-M7 are global work fields set in MR-000 and read/modified by MR-020, MR-030, MR-050, MR-060, MR-070. Every paragraph depends on specific WK-M* values set by other paragraphs.

**Era**: 1978 (TKN). Pre-structured programming — no local variables in COBOL.

**Why It Exists**: COBOL has no local scope. All variables are global. TKN used cryptic WK-M* names as "parameters" passed between paragraphs through shared memory.

**Risk**: Changing the meaning of WK-M4 in one paragraph silently breaks all others that read it. No compiler warning.

**Modern Equivalent**: PERFORM with USING clause (COBOL-2002), or dedicated record structures per operation.

---

### MR-03: COPY REPLACING (Namespace Collision Risk)

**What**: `COPY "COMCODE.cpy" REPLACING ==RESULT-CODES== BY ==MR-RESULT-CODES==` renames the common status codes to avoid name collisions with PAYROLL.cob's copy of the same file.

**Era**: 1981 (TKN).

**Why It Exists**: Multiple programs COPY the same copybook. Without REPLACING, field names collide if both are linked. TKN's workaround was textual replacement — a proto-namespace.

**Risk**: REPLACING is a text substitution, not a semantic rename. It can match substrings unexpectedly. If COMCODE.cpy adds a field containing "RESULT-CODES" in a comment, the comment gets mangled.

**Modern Equivalent**: Separate copybooks per domain, or OO-COBOL classes with encapsulation.

---

### MR-04: Implicit Scope Terminators (No END-IF)

**What**: All IF/ELSE chains throughout MERCHANT.cob terminate with periods instead of END-IF. A misplaced period terminates all open scopes silently.

**Era**: 1978 (TKN). COBOL-68 had no END-IF.

**Why It Exists**: TKN wrote in COBOL-68 style. Period-terminated IF was the only option.

**Risk**: Inserting a DISPLAY statement for debugging and accidentally adding a period terminates the IF chain, changing all subsequent ELSE matching.

---

### MR-05: Dead Paragraphs (MR-055, MR-085)

**What**: MR-055 (VIP merchant override) and MR-085 (auto-promotion scheduler) are never called from any other paragraph.

**Era**: 1979-1980 (TKN). MR-055 was for a VIP program that was cancelled. MR-085 was a prototype for automatic tier promotion.

**Why It Exists**: Features were abandoned but code was never removed. "It might be needed later."

---

### MR-06: Copy-Paste Degradation

**What**: MR-030 (onboard) uses named constants for volume thresholds. MR-072 (retier) was copy-pasted from MR-030 but uses inline magic numbers (50000, 500000) instead of the constants.

**Era**: 1979 (TKN). The retier operation was added in a hurry.

**Why It Exists**: TKN copied the onboarding logic for retier but "simplified" it by inlining the values. When thresholds change, MR-030 updates correctly but MR-072 keeps the old values.

---

## FEEENGN.cob Issues

### FE-01: SORT with INPUT/OUTPUT PROCEDURE

**What**: The main fee calculation uses `SORT SORT-FILE ON ASCENDING KEY SORT-FEE-TIER INPUT PROCEDURE IS FE-INPUT-PROC OUTPUT PROCEDURE IS FE-OUTPUT-PROC`. COBOL SORT takes control of execution — INPUT PROCEDURE RELEASEs records into the sort, OUTPUT PROCEDURE RETURNs them in order.

**Era**: 1986 (RBJ). SORT was considered the most efficient way to process tiered fee batches.

**Why It Exists**: Interchange fees differ by tier. Sorting by tier allows sequential processing with a single pass through each tier's rate table. The callback-style flow (RELEASE/RETURN) was idiomatic for batch COBOL.

**Risk**: The SORT verb hijacks normal program flow. Code between INPUT and OUTPUT PROCEDURE cannot use GO TO to leave the sort. Debugging requires understanding COBOL's coroutine-like SORT execution model.

**Modern Equivalent**: In-memory collection sort, or SQL ORDER BY.

---

### FE-02: Triple-Nested PERFORM VARYING

**What**: Fee calculation iterates 3 deep: `PERFORM VARYING WS-TIER-IDX FROM 1 BY 1 UNTIL WS-TIER-IDX > 4` → `PERFORM VARYING WS-MARKUP-IDX FROM 1 BY 1 UNTIL WS-MARKUP-IDX > 4` → `PERFORM VARYING WS-XBORDER-IDX FROM 1 BY 1 UNTIL WS-XBORDER-IDX > 3`. Total: O(4 * 4 * 3) = 48 iterations per transaction.

**Era**: 1986 (RBJ). "Exhaustive search for the right rate combination."

**Why It Exists**: The fee schedule is a 3-dimensional lookup: interchange tier x markup level x cross-border flag. RBJ modeled it as nested loops instead of a direct table lookup.

**Risk**: Adding a 4th dimension (e.g., currency) would make this O(N^4). Performance degrades multiplicatively.

**Modern Equivalent**: Direct table indexing: `FEE-RATE(tier, markup, xborder)`.

---

### FE-03: "Temporary" Blended Pricing Override (1989)

**What**: A flat 2.9% + $0.30 pricing override that bypasses the entire tiered calculation. Controlled by `WS-BLEND-ACTIVE` flag, which has been 'Y' since 1989. Comments say "temporary for Q2 1989."

**Era**: 1989 (RBJ). "Just for this quarter while we negotiate new interchange rates."

**Why It Exists**: Management wanted simplified pricing for a quarter. RBJ added a bypass flag. The flag was never turned off because the simplified pricing was "close enough" and nobody wanted to test the full tiered calculation again.

**Risk**: The entire tiered fee engine (SORT, nested loops, rate tables) executes but its result is overwritten by the blend. Hundreds of lines of dead-but-executing code.

---

### FE-04: Hardcoded Interchange Rates Contradict Copybook

**What**: WS-HARDCODED-RATES in WORKING-STORAGE has interchange rates (1.65%, 1.80%, 2.10%, 2.40%) that differ from FEEREC.cpy's table (which has different values). The program uses the hardcoded rates.

**Era**: 1986 (RBJ hardcoded), 1992 (RBJ updated Amex rate in WS but not in copybook).

**Why It Exists**: Same pattern as TX-04 in TAXCALC — developer didn't trust the copybook mechanism.

---

### FE-05: Dead Tier 4 Stub

**What**: FE-CALC-TIER-4 paragraph exists but only contains a DISPLAY and MOVE 0. Comments say "ACS to implement 1994."

**Era**: 1994 (ACS added the stub, then transferred to DISPUTE.cob work and never returned).

---

## DISPUTE.cob Issues

### DP-01: ALTER-Based State Machine

**What**: Chargeback state transitions (OPEN → REPRESENTED → PRE-ARB → WRITE-OFF) use ALTER to modify GO TO targets at runtime. `ALTER DP-ADVANCE-NEXT TO PROCEED TO DP-STATE-REPRESENTED` changes where the state transition paragraph jumps.

**Era**: 1994 (ACS). "ALTER is the cleanest way to model state transitions in COBOL."

**Why It Exists**: ACS modeled the chargeback lifecycle as a finite state machine. ALTER dynamically changes the "next state" pointer. This is technically elegant but impossible to trace statically.

**Risk**: Static analysis tools cannot determine which state the GO TO will reach without simulating the ALTER chain. Adding a new state requires updating multiple ALTER statements.

**Modern Equivalent**: EVALUATE with explicit state variable: `EVALUATE WS-STATE / WHEN 'OPEN' / WHEN 'REPRESENTED' / ...`

---

### DP-02: Dead Report Writer (RD Section)

**What**: A complete REPORT SECTION with RD (Report Description) entry, control headers, detail lines, and footers. The INITIATE/GENERATE/TERMINATE verbs are present but commented out. ACS started rewriting the dispute report output using Report Writer, then abandoned it when she transferred to CICS development.

**Era**: 1996 (ACS, last 2 months before transfer).

**Why It Exists**: Report Writer was meant to replace the manual STRING-based report formatting. The rewrite was 60% complete when ACS left. Nobody else understood Report Writer.

**Risk**: 80+ lines of dead declaratives. New developers waste time trying to understand why the RD section exists and whether it's used.

---

### DP-03: STRING/UNSTRING for Reason Code Parsing

**What**: Network reason codes are parsed by UNSTRING using delimiter "/" to extract code, sub-code, and description. The reverse operation uses STRING with DELIMITED BY SIZE to reassemble.

**Era**: 1995 (ACS).

**Why It Exists**: Chargeback reason codes arrive in network-specific formats (e.g., "4853/01/Item Not Received"). COBOL has no regex or split function — UNSTRING with delimiters is the only string parsing available.

**Risk**: If the delimiter appears inside the description field, UNSTRING splits incorrectly. ACS added no validation for this case.

---

### DP-04: Dual Advance Paths (ALTER vs PERFORM)

**What**: The ADVANCE operation has two code paths: one uses the ALTER state machine (correct transitions), the other uses direct PERFORM (skips CALC-REVERSAL for pre-arb states). Which path runs depends on `WS-USE-ALTER-PATH` flag.

**Era**: 1995 (ACS). "PERFORM path for quick testing, ALTER path for production."

**Why It Exists**: ACS needed a way to test state transitions without the ALTER complexity. She added a flag-gated shortcut that skips reversal computation. The flag defaults to 'Y' (ALTER path) in production.

**Risk**: If someone sets the flag to 'N' (PERFORM path), pre-arbitration disputes skip the reversal calculation, producing incorrect settlement amounts.

---

### DP-05: EVALUATE TRUE Nesting for Evidence Rules

**What**: Dispute evidence evaluation uses nested EVALUATE TRUE blocks — an EVALUATE inside another EVALUATE's WHEN clause, 3 levels deep.

**Era**: 1994 (ACS). "EVALUATE is the modern way to do this."

**Why It Exists**: ACS correctly chose EVALUATE over nested IF, but the dispute evidence rules are inherently complex (card-present vs card-not-present x reason code x evidence type x amount threshold). Three levels of EVALUATE is cleaner than the equivalent nested IF, but still hard to follow.

---

## RISKCHK.cob Issues

### RK-01: Contradicting Velocity Checks

**What**: KMW's `RK-VELOCITY-CHECK` scores >5 transactions/hour as +20 risk points. Offshore's `RK-VELOCITY-CHECK-V2` scores >20 transactions/day as +15 risk points. **Both run during every CHECK operation.** A customer with 6 transactions in one hour gets 20 + 15 = 35 points from velocity alone.

**Era**: 2008 (KMW: per-hour), 2009 (Offshore: per-day, added without removing KMW's).

**Why It Exists**: Offshore was told "add velocity checking" without being told it already existed. KMW's naming convention (`RK-CHECK-*`) differed from offshore's (`RK-*-V2`), making the duplicate invisible in code review.

**Risk**: Double-scoring causes false positives. Legitimate high-frequency merchants (gas stations, vending) get flagged on every batch run.

**Modern Equivalent**: Single velocity module with configurable time windows.

---

### RK-02: Duplicate Amount Scoring

**What**: `RK-CHECK-AMOUNT` (KMW) and `RK-AMOUNT-VALIDATION-ROUTINE` (Offshore) both score transaction amounts. A $9,500 transaction gets 35 points from KMW + 30 points from offshore = 65 points from amount alone — nearly breaching the 75-point threshold before any other factor.

**Era**: 2008 (KMW), 2011 (Offshore).

**Why It Exists**: Same pattern as RK-01 — offshore added a duplicate without discovering KMW's version. Different paragraph naming conventions masked the duplication.

---

### RK-03: Duplicate 88-Level Conditions with Conflicting Values

**What**: KMW defined `88 RK-HIGH-RISK VALUE 4 THRU 5` on `WS-TIER-CLASS`. Offshore defined `88 RK-RISKY VALUE 3 THRU 5` on `WS-TIER-LEVEL`. Both are checked in different paragraphs. Tier 3 merchants get 0 points from KMW but 10 points from offshore.

**Era**: 2008 (KMW), 2009 (Offshore).

**Why It Exists**: Two developers independently defined "high risk" with different thresholds on different variables. Neither checked for existing definitions.

**Risk**: Risk scoring is inconsistent — the same merchant gets different scores depending on which paragraph's check fires first.

---

### RK-04: INSPECT TALLYING for Keyword Detection

**What**: Five `INSPECT WS-INPUT-DESC TALLYING WS-KEYWORD-COUNT FOR ALL` statements scan transaction descriptions for suspicious keywords: "CASH", "WIRE", "URGENT", "OFFSHORE", "CRYPTO". Each hit adds 5 risk points.

**Era**: 2008 (KMW).

**Why It Exists**: COBOL has no regex. INSPECT TALLYING is the closest thing to a string search. KMW used it as a crude keyword-based fraud detector.

**Risk**: False positives on legitimate descriptions ("CASHIER'S CHECK", "WIRE TRANSFER FEE"). No word-boundary detection.

---

### RK-05: Dead ML Scoring Placeholder

**What**: `RK-ML-SCORE` paragraph hardcodes `MOVE 50 TO WS-ML-SCORE` then checks `IF WS-ML-SCORE > 70` — which never fires. Comments say "TODO: integrate ML model via CICS call." Dead variables `WS-GEO-LATITUDE`, `WS-GEO-LONGITUDE` (from "future geo-fencing") and `WS-ML-READY`, `WS-ML-AVAILABLE`.

**Era**: 2009 (Offshore). "Placeholder for machine learning integration."

**Why It Exists**: Offshore was asked to "prepare for ML scoring." They added a paragraph that returns a constant, with a conditional that never triggers. The ML integration never materialized.

---

### RK-06: 4-Level Nested IF with Misleading Comment

**What**: `RK-CHECK-AMOUNT` has 4 nested IFs without END-IF. KMW's inline comment claims `ELSE` matches the outermost IF (`>= 500`), but it actually matches the innermost (`>= 25000`). The wrong comment is intentional — it mirrors a real-world pattern where developers misunderstand their own nesting.

**Era**: 2008 (KMW).

**Why It Exists**: KMW wrote the nesting quickly and added a comment from memory, not from careful analysis. The comment was never verified.

**Risk**: A developer trusting the comment would incorrectly understand the scoring for amounts between $500 and $25,000.

---

## Summary: Anti-Pattern Frequency

| Anti-Pattern | Occurrences | Programs |
|-------------|-------------|----------|
| GO TO | 20+ | PAYROLL, DEDUCTN, MERCHANT, DISPUTE |
| ALTER | 6 | PAYROLL, DISPUTE |
| GO TO DEPENDING ON | 2 | MERCHANT |
| PERFORM THRU | 3 | PAYROLL, TAXCALC |
| Nested IF (no END-IF) | 3 | TAXCALC (6-level), MERCHANT, RISKCHK (4-level) |
| SORT INPUT/OUTPUT PROCEDURE | 1 | FEEENGN |
| COPY REPLACING | 1 | MERCHANT |
| INSPECT TALLYING | 5 | RISKCHK |
| STRING/UNSTRING | 2 | DISPUTE |
| Nested EVALUATE | 1 (3-level) | DISPUTE |
| Nested PERFORM VARYING | 1 (3-deep) | FEEENGN |
| Dead paragraphs | 9 | All 8 programs |
| Dead Report Writer (RD) | 1 | DISPUTE |
| Dead ML placeholder | 1 | RISKCHK |
| Misleading comments | 6 | TAXCALC, DEDUCTN, PAYCOM, RISKCHK |
| Magic numbers | 10+ | PAYROLL, MERCHANT, FEEENGN |
| Mixed COMP types | 3+ records | DEDUCTN, EMPREC |
| Y2K artifacts | 3 | PAYBATCH |
| Dead constants | 4 | PAYCOM |
| Comment/value mismatch | 5 | PAYCOM, TAXCALC, DEDUCTN, FEEENGN |
| Conflicting values | 4 | PAYCOM, RISKCHK (velocity, amount, tier) |
| Contradicting fixes (dual) | 3 | RISKCHK (velocity, amount, tier) |
| Copy-paste degradation | 1 | MERCHANT |
| Shared WS coupling | 7 fields | MERCHANT |
| "Temporary" overrides | 1 (37 years) | FEEENGN (blended pricing since 1989) |
| Dual code paths | 1 | DISPUTE (ALTER vs PERFORM) |
