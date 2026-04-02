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

## Enrichment Issues (Spaghetti Enrichment Workstream)

The following issues document deeper archaeological artifacts added during the Spaghetti Enrichment workstream — practitioner war stories, mainframe heritage, and silent-failure patterns drawn from `COBOL_PRACTITIONER_INSIGHTS.md` and `COBOL_MAINFRAME_QUIRKS.md`.

---

### PY-06: Period Bug Risk in Deductions (P-060)

**What**: If the period after the medical deduction END-IF were missing, the ELSE path would extend into the dental calculation, doubling deductions for employees without premium medical.

**Era**: Universal COBOL risk. Referenced: Nordea bank 16-hour outage from a missing period in a cash register module.

**Why It Exists**: COBOL sentences are terminated by periods, not by END-IF. A missing period causes fall-through — the next sentence executes as part of the current one. This is silent and catastrophic.

**Risk**: Self-DOS. The entire payroll run produces wrong deduction amounts with no error message.

**Modern Equivalent**: Always use explicit END-IF scope terminators (COBOL-85+). Lint tools can detect unterminated IF scopes.

---

### PY-07: Numeric Overflow in Batch Totals

**What**: `WS-BATCH-GROSS` (PIC S9(9)V99) silently truncates if batch total exceeds $999,999,999.99. No ON SIZE ERROR handler.

**Era**: 1991 (SLW).

**Why It Exists**: Field size was "big enough" for the original 25-employee payroll. Nobody recalculated when the system scaled.

**Risk**: High-order digits vanish silently. Batch totals reported to accounting are wrong.

**Modern Equivalent**: PIC S9(13)V99 COMP-3 (banking standard), with ON SIZE ERROR handler.

---

### PY-08: MOVE Truncation and Implied Decimal Traps

**What**: Numeric MOVEs are right-justified and left-truncated (`MOVE 1000005 TO PIC 9(6)` stores `000005`). Multiplying two PIC 9(4)V99 fields requires PIC 9(8)V9(4) receiving field.

**Era**: COBOL language design (1959). Defined behavior, not a bug.

**Why It Exists**: Fixed-precision arithmetic by design. The V (implied decimal) occupies zero bytes of storage. Truncation, not rounding, is the default.

**Risk**: High-order digits and decimal places vanish without any error or warning.

**Modern Equivalent**: Use ROUNDED and ON SIZE ERROR on every COMPUTE. Size receiving fields for worst-case arithmetic results.

---

### PY-09: McCracken ALTER Quote and Debugging Trap

**What**: ALTER makes GO TO targets change at runtime. Daniel McCracken (1976): "The sight of a GO TO statement in a paragraph by itself...strikes fear in the heart of the bravest programmer."

**Era**: 1974 (JRK). ALTER deprecated in COBOL-85, removed in COBOL-2002.

**Why It Exists**: Before EVALUATE, ALTER was the standard dispatch mechanism. One site left debug DISPLAYs in production, generating 4GB of spool output.

**Risk**: Static analysis cannot determine GO TO targets. Debugging requires runtime tracing.

**Modern Equivalent**: EVALUATE TRUE / WHEN / PERFORM.

---

### PY-10: Banker's Rounding Not Implemented

**What**: COBOL's ROUNDED phrase defaults to round-half-up. Banking requires round-half-to-even (banker's rounding) which must be coded explicitly.

**Era**: COBOL language design. COBOL-2002 added ROUNDED MODE IS NEAREST-EVEN but most production code predates this.

**Why It Exists**: ROUNDED alone is not sufficient for financial compliance. 0.005 rounds to 0.01 (half-up) instead of 0.00 (half-to-even).

**Risk**: Systematic upward bias in rounding accumulates over millions of transactions.

**Modern Equivalent**: ROUNDED MODE IS NEAREST-EVEN (COBOL-2002+), or explicit half-to-even logic.

---

### TX-07: Implied Decimal Zero-Byte Storage

**What**: The V in PIC 9V9999 occupies ZERO bytes. Rate 0.2200 stored as "02200". Moving 80.375 into PIC 9(6)V99 silently stores 80.37 — truncation, not rounding.

**Era**: COBOL language design (1959).

**Why It Exists**: Fixed-point arithmetic avoids floating-point representation errors entirely. The tradeoff is silent truncation.

**Risk**: Tax calculations lose fractional cents. Over 26 pay periods, rounding errors accumulate.

**Modern Equivalent**: COMPUTE with ROUNDED ON SIZE ERROR. Use intermediate fields with extra decimal places.

---

### TX-08: PERFORM THRU Armed Mine Pattern

**What**: A GO TO that jumps out of a PERFORM THRU range leaves a return address on COBOL's internal control stack. Later execution through the exit paragraph detonates an unexpected jump.

**Era**: COBOL-68 pattern. Practitioners call these "armed mines."

**Why It Exists**: PERFORM THRU was standard practice before structured programming. Inserting a paragraph within a THRU range silently adds it to the execution scope.

**Risk**: Behavior invisible in source code. Maintenance programmers unknowingly arm mines.

**Modern Equivalent**: PERFORM single paragraphs. Never use PERFORM THRU in new code.

---

### TX-09: Banking Day-Count Conventions

**What**: Tax/interest calculations should specify day-count conventions: 30/360 (corporate bonds), Actual/360 (money markets), Actual/365 (UK), Actual/Actual (US Treasuries).

**Era**: Banking standard. TAXCALC.cob uses flat rates without day-count specification.

**Why It Exists**: PMR simplified tax as flat percentage of gross. Real banking calculates interest using INTEGER-OF-DATE intrinsic and explicit day counts.

**Risk**: Using wrong convention on a 30-year mortgage changes total interest by thousands of dollars.

**Modern Equivalent**: Explicit day-count convention parameter with INTEGER-OF-DATE for actual-day calculations.

---

### DD-06: Accidental Period Bug Avoidance

**What**: SLW's 2 AM GO TO in DEDUCTION-OVERFLOW-HANDLER accidentally avoided a period bug that would have doubled medical deductions.

**Era**: 1991 (SLW production fix).

**Why It Exists**: The GO TO placement was "close enough" — accidental correctness, not design.

**Risk**: Refactoring the GO TO could reintroduce the period bug. The safety depends on accident, not intent.

**Modern Equivalent**: Structured IF/END-IF with explicit scope terminators.

---

### DD-07: MOVE CORRESPONDING Silent Field Drops

**What**: MOVE CORRESPONDING matches fields by NAME across groups. Renaming a field in one group silently drops it from the CORRESPONDING operation.

**Era**: COBOL language design. DEDUCTN.cob documents the pattern.

**Why It Exists**: No compiler warning when a field name doesn't match. The operation simply skips the unmatched field.

**Risk**: Renaming for clarity silently breaks data flow. Discovered only through wrong output values.

**Modern Equivalent**: Explicit MOVE statements for each field. MOVE CORRESPONDING is convenient but fragile.

---

### DD-08: Dead FSA Deduction Paragraph

**What**: DEAD-FLEX-SPENDING paragraph and associated WS-DEAD-FSA-ANNUAL, WS-DEAD-HSA-ANNUAL, WS-DEAD-COBRA-FLAG fields — all unreferenced.

**Era**: 1992 (SLW). Benefits administration moved to external system in 1993.

**Why It Exists**: SLW started implementation, then the requirement moved to ADP's outsourced system. Code was never cleaned up.

**Risk**: None (dead code). Increases maintenance confusion.

**Modern Equivalent**: Delete dead code. Track feature intent in issue trackers, not source files.

---

### PB-05: Batch Ordering Assumption

**What**: EMPLOYEES.DAT is assumed pre-sorted by bank code. No validation enforces this — unsorted input produces interleaved outbound records.

**Era**: 2002 (Y2K team assumed existing data ordering).

**Why It Exists**: The original JCL job had a SORT step before PAYBATCH. When migrated to GnuCOBOL, the SORT step was lost.

**Risk**: SETTLE.cob downstream assumes grouped records per bank. Interleaved records cause incorrect settlement amounts.

**Modern Equivalent**: Either validate sort order at input, or sort within the program using SORT verb.

---

### PB-06: Y2K Windowing Expiration

**What**: WS-Y2K-PIVOT (50) means 2-digit year >= 50 → 19XX. A 30-year mortgage from 2020 matures in 2050 → interpreted as 1950.

**Era**: 2002 (Y2K team). Windowing was a "temporary" fix.

**Why It Exists**: Full 4-digit year conversion was too expensive. Windowing deferred the problem by ~50 years. Those years are expiring.

**Risk**: Date-dependent calculations (aging, interest, compliance deadlines) silently produce wrong results after the pivot year.

**Modern Equivalent**: Full 4-digit year fields (PIC 9(8) YYYYMMDD). IBM DATEPROC and YEARWINDOW compiler options for legacy code.

---

### PB-07: JCL and Batch Heritage

**What**: SELECT/ASSIGN → JCL DD mapping, DISP parameters (OLD/SHR/MOD), GDG versioning, compile-link-go sequence documented in header comments.

**Era**: z/OS batch infrastructure.

**Why It Exists**: COBOL programs don't "own" their files — JCL controls all physical I/O allocation. Migration to GnuCOBOL replaces JCL with shell scripts.

**Risk**: JCL-dependent assumptions (exclusive locks, GDG versioning, COND codes) don't translate to POSIX environments.

**Modern Equivalent**: Shell scripts with explicit file locking (flock), versioned output directories, and exit code checking.

---

### PB-08: EOD Batch Sequence Dependencies

**What**: PAYBATCH would be step 2 of a 9-step nightly cycle: quiesce → post → accrue interest → assess fees → age loans → FX reval → regulatory → GL → date roll.

**Era**: Standard banking operations.

**Why It Exists**: Each step depends on prior steps' completion. Job schedulers (CA-7, TWS/OPC, Control-M) enforce dependencies.

**Risk**: Running steps out of order or after a prior step's failure produces cascading data corruption.

**Modern Equivalent**: Workflow orchestration (Airflow, Step Functions) with explicit dependency graphs and failure handling.

---

### PC-04: Banking Standard PIC Sizes

**What**: PAYCOM uses PIC S9(7)V99 for monetary amounts. Banking standard is PIC S9(13)V99 COMP-3 (8 bytes, up to ±$999 trillion).

**Era**: 1974 (JRK). Field sizes were "big enough" for the original payroll.

**Why It Exists**: Storage was expensive in 1974. PIC S9(7)V99 was sufficient for employee salaries.

**Risk**: Cannot handle institutional banking amounts. Account balances over $99,999.99 overflow silently.

**Modern Equivalent**: PIC S9(13)V99 COMP-3 for amounts, PIC 9(3)V9(6) COMP-3 for rates, PIC S9(15)V9(6) COMP-3 for intermediates.

---

### PC-05: COMP-3 Cross-Platform Compatibility

**What**: COMP-3 packed decimal is byte-identical between IBM and GnuCOBOL. COMP-1/COMP-2 floating point is completely incompatible (hex float vs IEEE 754).

**Era**: Hardware architecture difference.

**Why It Exists**: IBM z-Series uses hexadecimal floating point; all other platforms use IEEE 754. Packed decimal (BCD) is a universal encoding.

**Risk**: Using COMP-1/COMP-2 for cross-platform financial data produces silently wrong results.

**Modern Equivalent**: Use COMP-3 exclusively for financial data interchange. Avoid COMP-1/COMP-2 in portable code.

---

### ER-03: Numeric Storage Format Comparison

**What**: EMPREC.cpy documents three storage formats with byte-level examples: DISPLAY (+123 as F1 F2 C3), COMP (binary size breakpoints), COMP-3 (packed as 12 34 5C).

**Era**: COBOL language design (1959-1985).

**Why It Exists**: Each format trades storage size vs. performance vs. compatibility. COMP-3 is the banking standard because IBM z-Series has native BCD instructions.

**Risk**: Mixing formats causes implicit conversions on every COMPUTE, degrading performance and potentially changing precision.

**Modern Equivalent**: Standardize on COMP-3 for all financial fields. Use COMP only for integer counters and indexes.

---

### ER-04: Overpunch Sign Encoding

**What**: Signed DISPLAY fields encode the sign in the zone nibble of the last byte. EBCDIC positive: 0={, 1=A...9=I. Negatives: 0=}, 1=J...9=R. ASCII Micro Focus uses different encoding.

**Era**: EBCDIC hardware encoding (1964).

**Why It Exists**: IBM mainframes use EBCDIC, which stores the sign as a zone nibble. A character-for-character EBCDIC↔ASCII translation corrupts signed numeric fields.

**Risk**: Python parsers must handle overpunch explicitly or every negative value becomes garbage data.

**Modern Equivalent**: COMP-3 avoids overpunch entirely. When processing DISPLAY format, use explicit overpunch decoding tables.

---

### ER-05: Memory Alignment and SYNCHRONIZED Clause

**What**: COMP fields should fall on halfword (2-byte) or fullword (4-byte) boundaries for optimal z/OS performance. SYNCHRONIZED inserts slack bytes that change record length.

**Era**: IBM System/360 architecture (1964).

**Why It Exists**: Hardware fetches data on natural boundaries. Misaligned access requires two fetch cycles.

**Risk**: Adding SYNCHRONIZED to a copybook changes LRECL, breaking every program and JCL SORT that hardcodes the record length.

**Modern Equivalent**: Design record layouts with alignment in mind from the start. Document LRECL explicitly.

---

### MR-07: WK-M4 Triple Field Reuse

**What**: WK-M4 (PIC 9(1)) has three different meanings: known-MCC flag in MR-030, risk score in MR-040, fee tier index in MR-072.

**Era**: 1978 (TKN). Shared WORKING-STORAGE was the "parameter passing" mechanism.

**Why It Exists**: TKN used single-character work fields as globals. Each paragraph reads/writes the same field for different purposes.

**Risk**: Changing the dispatch order causes all three meanings to collide. A risk score of 5 becomes a fee tier of 5.

**Modern Equivalent**: Dedicated named fields for each purpose. Use CALL...USING for parameter passing between modules.

---

### MR-08: CICS vs Batch Working-Storage Persistence

**What**: In batch, WORKING-STORAGE persists. In CICS, each task gets a fresh copy. WK-M1..M7 reset between pseudo-conversational transactions unless state goes through COMMAREA.

**Era**: CICS architecture (1968).

**Why It Exists**: CICS runs multiple concurrent transactions sharing one address space. Fresh WS copy prevents cross-task contamination.

**Risk**: Online-to-batch conversion forgets that batch WS persists, leaving stale values from previous iterations.

**Modern Equivalent**: Explicit state management. In CICS: COMMAREA or Channels/Containers. In batch: initialize all fields at loop start.

---

### MR-09: DB2 DCLGEN Heritage

**What**: WS-DEAD-DCLGEN-TIMESTAMP documents DB2's DCLGEN utility that generates COBOL copybooks from table definitions. Host variables prefixed with `:` in SQL.

**Era**: 1994 (ACS port from DB2 to flat files).

**Why It Exists**: The original MERCHANT program used EXEC SQL with embedded DB2 access. GnuCOBOL port replaced SQL with file I/O.

**Risk**: None (dead fields). Documents the architectural heritage for future maintainers.

**Modern Equivalent**: ORM layers, database migration tools, schema-first design.

---

### FE-06: SORT Failure Recovery and IPL

**What**: SORT failure leaves SORT-WORK file locked. On IBM z/OS, recovery required an IPL (Initial Program Load) — a 2-hour system restart. Lost the Sunday batch window twice in 1988.

**Era**: 1986 (RBJ).

**Why It Exists**: SORT takes exclusive control of the work file. Abnormal termination doesn't release the lock on early z/OS versions.

**Risk**: SORT abend blocks all subsequent batch jobs that need the sort work space.

**Modern Equivalent**: Modern z/OS has RESET SORTWORK. GnuCOBOL SORT failures are recoverable (temporary files cleaned up by OS).

---

### FE-07: Multi-Currency ISO 4217 Pattern

**What**: Real banking pairs every amount with its ISO 4217 currency code (PIC X(3)) and decimal-places indicator (PIC 9(1)). JPY uses 0 decimal places; BHD uses 3.

**Era**: International banking standard.

**Why It Exists**: FEEENGN.cob is USD-only but documents the pattern in dead WS fields (WS-DEAD-CURRENCY-CODE, WS-DEAD-DECIMAL-PLACES).

**Risk**: Processing JPY amounts with 2-decimal arithmetic multiplies yen values by 100. Processing BHD with 2 decimals loses the third.

**Modern Equivalent**: Currency-aware amount types that carry their own precision. ISO 4217 lookup table.

---

### FE-08: EBCDIC Sort Order Migration Bug

**What**: The SORT verb uses the platform's native collating sequence. EBCDIC: 'a' < 'A' < '1'. ASCII: '1' < 'A' < 'a'. Merchant IDs sorted on z/OS are in DIFFERENT order on GnuCOBOL.

**Era**: IBM mainframe architecture.

**Why It Exists**: RBJ never specified PROGRAM COLLATING SEQUENCE IS. The default depends on the platform.

**Risk**: Sorted output differs between platforms. Downstream programs expecting EBCDIC order produce wrong results on ASCII.

**Modern Equivalent**: Explicit COLLATING SEQUENCE specification, or platform-independent comparison logic.

---

### DP-06: Abend Mid-State-Transition Recovery

**What**: If DISPUTE.cob ABENDs between ALTER and REWRITE, the dispute record is in inconsistent state. Recovery: manually reset DISP-STATE to 'O'. Cost: 4 hours (ACS, 1995-11-22).

**Era**: 1994 (ACS).

**Why It Exists**: ALTER-based state machines have no transaction rollback. A crash mid-transition leaves partial state.

**Risk**: Dispute records stuck in invalid states require manual data correction.

**Modern Equivalent**: Database transactions with COMMIT/ROLLBACK. State machine with explicit transition validation.

---

### DP-07: FD Implicit REDEFINES

**What**: All 01-levels under an FD implicitly redefine each other — the file buffer is a single storage area. VALUE clauses on redefining items produce undefined behavior.

**Era**: COBOL language design.

**Why It Exists**: The file buffer is shared memory. Each record description is an overlay of the same bytes.

**Risk**: Initializing FD record fields with VALUE clause can be overwritten by the first READ. Multiple record types under one FD create type-unsafe unions.

**Modern Equivalent**: Separate file definitions or explicit REDEFINES with type guards (88-level conditions).

---

### DP-08: DB2/SQL Heritage Fields

**What**: WS-DEAD-SQLCODE (PIC S9(9) COMP), WS-DEAD-SQLCA-LEN, WS-DEAD-CICS-RESP, WS-DEAD-ABEND-HANDLER — all dead fields documenting the DB2/CICS heritage.

**Era**: 1994 (ACS original DB2 version), ported to file I/O for GnuCOBOL.

**Why It Exists**: EXEC SQL...END-EXEC with host variables (: prefix), SQLCA codes (0=success, +100=not found, -803=duplicate, -811=multiple rows), CICS SYNCPOINT for commits.

**Risk**: None (dead). Documents that this program was originally a DB2/CICS online transaction.

**Modern Equivalent**: SQLite (our Python bridge), ORM layers, prepared statements.

---

### RK-07: Midnight Boundary Velocity Reset

**What**: The "per-hour" velocity check resets at midnight. 10 transactions at 23:59 + 10 at 00:01 = two bursts of 10, not one burst of 20.

**Era**: 2008 (KMW).

**Why It Exists**: KMW's check compares transaction hour to current hour — no window spanning midnight.

**Risk**: Structured attackers split activity across midnight to avoid hourly thresholds.

**Modern Equivalent**: Rolling window (last 60 minutes regardless of clock hour). Sliding window counters.

---

### RK-08: Regulatory Compliance (CTR/SAR/OFAC)

**What**: Dead fields document CTR ($10K), SAR (structuring detection), OFAC (SDN list screening), and SWIFT message formats (MT103/MT202/MT940, ISO 20022 transition).

**Era**: Banking regulatory requirements (BSA 1970, USA PATRIOT Act 2001).

**Why It Exists**: Real banking risk engines feed into mandatory regulatory reporting. Our dead fields document the pattern.

**Risk**: None (dead). On a real system, missing CTR/SAR filing is a federal crime.

**Modern Equivalent**: Automated compliance engines with real-time screening, fuzzy name matching, and regulatory reporting pipelines.

---

### RK-09: Double-Scoring Root Cause

**What**: Both KMW and offshore paths accumulate into WS-RISK-SCORE without resetting between phases. This is the root cause of the double-scoring documented in RK-01/RK-02.

**Era**: 2008 (KMW) + 2009 (Offshore).

**Why It Exists**: Neither developer wanted to refactor the other's code. The accumulation was not a feature — it was mutual avoidance.

**Risk**: Legitimate transactions get flagged. The combined maximum score (220+) can theoretically overflow PIC 9(3), wrapping to 0.

**Modern Equivalent**: Separate scoring phases with explicit aggregation. Maximum score normalization.

---

### RK-10: Level 88 Semantics Documentation

**What**: Level 88 conditions are "COBOL's most underappreciated feature" — they allocate no storage, support multiple values and ranges, and centralize validation logic.

**Era**: COBOL-85 standardized 88-levels. The feature predates this in vendor extensions.

**Why It Exists**: RISKCHK.cob uses extensive 88-levels but the conflicting definitions (KMW HIGH=4-5 vs OFS RISKY=3-5) show how 88-levels can create confusion when multiple developers add overlapping conditions.

**Risk**: Contradicting 88-levels on different fields create different definitions of "high risk" in the same program.

**Modern Equivalent**: Enum types with explicit mapping. Validation middleware that enforces single source of truth.

---

### FR-01: OCCURS 4 Array Boundary Overflow

**What**: FEE-INTERCHANGE-ENTRY OCCURS 4 TIMES — network index 5 overflows. GnuCOBOL may raise EC-RANGE-INDEX; IBM z/OS silently overwrites adjacent memory.

**Era**: 1986 (RBJ). Four networks (Visa, MC, Amex, Discover).

**Why It Exists**: COBOL arrays have no runtime bounds checking on IBM mainframes. Subscript overflow writes into whatever memory follows.

**Risk**: Buffer overflow in COBOL. Adding a fifth network without updating OCCURS corrupts the markup tier table.

**Modern Equivalent**: Dynamic arrays, bounds checking, or OCCURS DEPENDING ON with explicit limit validation.

---

### FR-02: Contradicting Blend Rate Comment

**What**: Comment says "2.9% matches current Visa interchange." FEE-INTERCHANGE-ENTRY(1) has Visa rate at 0.0175 (1.75%). The 2.9% is the blended merchant discount rate, not interchange.

**Era**: 1989 (RBJ).

**Why It Exists**: RBJ conflated interchange rate (what the network charges) with merchant discount rate (what the merchant pays). Common confusion in payments.

**Risk**: Future developers may adjust the wrong rate based on the comment.

**Modern Equivalent**: Separate, clearly named fields for each rate component with inline documentation.

---

### MRC-01: REDEFINES S0C7 Risk

**What**: MERCH-AGGREGATE-DATA REDEFINES MERCH-INDIVIDUAL-DATA — reading aggregate fields when type is 'I' performs arithmetic on character data, triggering S0C7 on z/OS.

**Era**: 1978 (TKN).

**Why It Exists**: REDEFINES is COBOL's union with no discriminator enforcement. The 88-level type guard exists but is not checked in MR-072 (RETIER).

**Risk**: S0C7 data exception abend on IBM z/OS. GnuCOBOL may produce garbage silently.

**Modern Equivalent**: Tagged unions, discriminated records, or separate record types.

---

### DR-01: Evidence Flag PIC vs Comment Mismatch

**What**: Comment says "bitmap supports 8 evidence types in 2 bytes." PIC X(2) provides 2 character positions, not 8 bits.

**Era**: 1994 (ACS).

**Why It Exists**: ACS designed for a bitmap but coded character flags. The comment describes intent, not implementation.

**Risk**: Future developer implements bit manipulation on PIC X(2) expecting 16 bits, gets 2 characters.

**Modern Equivalent**: PIC X(8) with Y/N per position, or PIC 9(8) with digit-per-flag, or actual bitmap with INSPECT/TALLYING.

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
| Dead paragraphs | 16 | All 8 programs |
| Dead WS fields | 40+ | All 8 programs |
| Dead Report Writer (RD) | 1 | DISPUTE |
| Dead ML placeholder | 1 | RISKCHK |
| Misleading comments | 12+ | TAXCALC, DEDUCTN, PAYCOM, RISKCHK, all copybooks |
| Magic numbers | 10+ | PAYROLL, MERCHANT, FEEENGN |
| Mixed COMP types | 3+ records | DEDUCTN, EMPREC |
| Y2K artifacts | 3 | PAYBATCH |
| Y2K windowing expiration | 2 | PAYBATCH, PAYROLL |
| Dead constants | 4 | PAYCOM |
| Comment/value mismatch | 10+ | PAYCOM, TAXCALC, DEDUCTN, FEEENGN, MERCHREC, FEEREC, DISPREC |
| Conflicting values | 4 | PAYCOM, RISKCHK (velocity, amount, tier) |
| Contradicting fixes (dual) | 3 | RISKCHK (velocity, amount, tier) |
| Contradicting 88-levels | 8 | All 8 programs (dead fields) |
| Copy-paste degradation | 1 | MERCHANT |
| Shared WS coupling | 7 fields | MERCHANT |
| "Temporary" overrides | 1 (37 years) | FEEENGN (blended pricing since 1989) |
| Dual code paths | 1 | DISPUTE (ALTER vs PERFORM) |
| Period bug risk | 3 | PAYROLL, TAXCALC, DEDUCTN |
| Numeric overflow (silent) | 3 | PAYROLL, FEEENGN, RISKCHK |
| Implied decimal traps | 3 | TAXCALC, PAYROLL, FEEENGN |
| MOVE truncation hazards | 3 | PAYROLL, MERCHANT, DEDUCTN |
| REDEFINES safety (S0C7) | 3 | MERCHREC, DISPUTE, MERCHANT |
| EBCDIC sort order deps | 3 | MERCHANT, FEEENGN, RISKCHK |
| Copybook dependency chains | 7 | All 7 copybooks |
| CICS vs batch WS persistence | 2 | MERCHANT, DISPUTE |
| PERFORM THRU armed mines | 2 | TAXCALC, PAYROLL |
| Numeric storage formats | 3 | EMPREC (3-format comparison), PAYCOM, TAXREC |
| JCL/dataset/batch heritage | 2 | PAYBATCH, PAYROLL |
| FILE STATUS code awareness | 4 | FEEENGN, RISKCHK, PAYROLL, MERCHANT |
| Banking arithmetic | 3 | TAXCALC, FEEENGN, PAYROLL |
| DB2/SQL heritage | 2 | DISPUTE, MERCHANT |
| Level number semantics | 3 | RISKCHK (88-levels), DEDUCTN (66 RENAMES), PAYROLL (77) |
| Dialect/migration awareness | 3 | PAYROLL (NIST tests), MERCHANT (CICS/TSB), PAYBATCH (JCL) |
| Regulatory compliance | 1 | RISKCHK (CTR/SAR/OFAC/SWIFT) |
| Array bounds overflow | 2 | FEEREC (OCCURS 4), RISKCHK (PIC 9(3) wrap) |
| Midnight/timezone hazards | 3 | RISKCHK, PAYBATCH, PAYROLL |
| Input validation apathy | 3 | PAYROLL, RISKCHK, DISPUTE |
| 3270 terminal heritage | 2 | MERCHANT, PAYROLL |
| Batch ordering assumptions | 3 | PAYBATCH, FEEENGN, RISKCHK |
| Abend/recovery notes | 3 | DISPUTE, FEEENGN, PAYROLL |
