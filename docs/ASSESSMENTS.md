# Graded Assessments

**Course**: COBOL Legacy Systems — Observability & Modernization
**Prerequisite**: Complete Teaching Guide lessons 1-8

---

## Lab 1: Account Status Extension (Lesson 3)

**Objective**: Add a FREEZE account status to the banking system.

### Requirements

1. Modify `COBOL-BANKING/copybooks/COMCODE.cpy` to add status code `F` (Frozen) alongside existing codes `A` (Active) and `C` (Closed).
2. Modify `COBOL-BANKING/src/VALIDATE.cob` to reject transactions (DEPOSIT, WITHDRAW, TRANSFER) against frozen accounts with status code `04`.
3. Add a test in `python/tests/test_bridge.py` that:
   - Creates an account with status `F`
   - Attempts a deposit against it
   - Asserts the transaction is rejected with status `04`

### Deliverables

- Modified `.cob` and `.cpy` files
- New test case (must pass with `make test`)
- Brief write-up (3-5 sentences): Why is FREEZE different from CLOSE? What real-world banking scenario uses it?

### Rubric

| Criteria | Points |
|----------|--------|
| COMCODE.cpy updated correctly (88-level condition) | 15 |
| VALIDATE.cob rejects frozen accounts | 25 |
| Test case passes | 25 |
| Existing tests still pass (no regressions) | 20 |
| Write-up demonstrates understanding | 15 |
| **Total** | **100** |

---

## Lab 2: Manual Trace vs Analyzer (Lesson 7)

**Objective**: Manually trace execution flow through spaghetti COBOL, then verify your findings with the analysis tools.

### Requirements

1. Open `COBOL-BANKING/payroll/src/PAYROLL.cob` and manually trace execution starting from `P-000` (the entry point).
   - Document the paragraph execution order for a **salaried employee** (EMP-TYPE = 'S').
   - Document the paragraph execution order for an **hourly employee** (EMP-TYPE = 'H').
   - Identify which `ALTER` statements modify which `GO TO` targets.

2. Use the Analysis tab in the web console to run the call graph analyzer on PAYROLL.cob.
   - Compare the tool's output with your manual trace.
   - Identify any paragraphs the tool found that you missed (or vice versa).

3. Answer: What is the execution path when `ALTER P-030 TO PROCEED TO P-040` runs? Which paragraph does P-030's `GO TO` jump to before and after the ALTER?

### Deliverables

- Hand-drawn or text-based execution flow diagram (both paths)
- Screenshot of the analyzer's call graph
- Comparison write-up (differences between manual and automated analysis)
- Answer to the ALTER question with line number references

### Rubric

| Criteria | Points |
|----------|--------|
| Salaried path traced correctly (all paragraphs in order) | 20 |
| Hourly path traced correctly | 20 |
| ALTER targets identified correctly | 15 |
| Analyzer comparison is substantive (not just "they match") | 20 |
| ALTER question answered with line references | 15 |
| Diagram is clear and readable | 10 |
| **Total** | **100** |

---

## Lab 3: Anti-Pattern Discovery (Lesson 9)

**Objective**: Find and document a new anti-pattern in the payment processing sidecar.

### Requirements

1. Choose one of the following programs:
   - `DISPUTE.cob` (ALTER state machine, dead Report Writer code)
   - `RISKCHK.cob` (contradicting fixes, duplicate scoring)
   - `MERCHANT.cob` (GO TO DEPENDING ON, dead paragraphs)
   - `FEEENGN.cob` (SORT with INPUT/OUTPUT PROCEDURE, contradicting rates)

2. Find an anti-pattern that is **not already documented** in `COBOL-BANKING/payroll/KNOWN_ISSUES.md`.
   - Hint: Each program has at least 2 undocumented anti-patterns beyond what KNOWN_ISSUES covers.

3. Write a `KNOWN_ISSUES.md` entry following the existing format:
   ```
   ### XX-NN: Title

   **What**: Description of the anti-pattern.

   **Era**: Year (developer initials). Context of when it was written.

   **Why It Exists**: The rational decision that led to this code.

   **Risk**: What breaks if the pattern is extended or modified.

   **Modern Equivalent**: What a developer would write today.
   ```

4. Use the complexity analyzer (Analysis tab or API) to get the paragraph's complexity score. Include the score in your entry.

### Deliverables

- One complete KNOWN_ISSUES entry (following the format above)
- Complexity score from the analyzer
- 2-3 sentence reflection: Why was this anti-pattern "correct" at the time?

### Rubric

| Criteria | Points |
|----------|--------|
| Anti-pattern is real (verifiable in the source code) | 25 |
| Entry follows the KNOWN_ISSUES format exactly | 15 |
| Era/developer attribution is plausible | 10 |
| Risk assessment is specific (not generic) | 15 |
| Modern equivalent is practical | 10 |
| Complexity score included and interpreted | 10 |
| Reflection shows historical empathy | 15 |
| **Total** | **100** |

---

## Submission Guidelines

- Submit via your institution's LMS or as a git branch (ask your instructor)
- All code changes must pass `make test` with zero failures
- Late submissions: -10 points per day (max -30)
- Academic integrity: You may use the analysis tools and LLM chat for research, but all written analysis must be your own words
