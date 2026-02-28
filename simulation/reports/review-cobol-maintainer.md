# Marcus Chen — Senior COBOL Systems Programmer, IBM Z

**25 years maintaining CICS/batch COBOL on z/OS at a top-5 US bank**

## Rating: 4.2 / 5 stars

---

## First Impressions

I came in skeptical. I've seen a hundred "learn COBOL!" projects on GitHub that get the syntax right and everything else wrong. This one is different. The first thing I noticed was the production-style headers on every .cob file — program name, system, node, author, purpose, file inventory, change log. That's not something you learn from a textbook. That's something you learn from staring at 30-year-old source on a 3270 terminal.

The six-node architecture with a clearing house immediately told me the author understands how banking actually works. Not a toy single-bank system — a proper distributed settlement network with nostro accounts.

---

## What Works

**Authentic COBOL patterns:**
- The `ACCTREC.cpy` copybook at 70 bytes is realistic. Real mainframe records are 80-column card images. Close enough.
- `FILE STATUS IS WS-FILE-STATUS` on every SELECT — this is non-negotiable in production COBOL and they got it right.
- The `COPY` statement usage with shared copybooks across multiple programs mirrors real-world copybook libraries.
- `OPEN EXTEND` for transaction logs, `OPEN OUTPUT` for account rewrites — correct I/O patterns.
- The 88-level condition names (`WS-FILE-OK VALUE '00'`) are textbook but practical.
- `PIC S9(10)V99` for financial amounts with implied decimal — exactly right. No floating point.

**The settlement flow is correct:**
- 3-leg settlement (debit source nostro, credit dest nostro, write audit trail) is how real clearing houses work.
- NSF checks on nostro accounts before settlement — a detail most tutorials skip.
- The OUTBOUND.DAT pattern with dynamic file path assignment (`ASSIGN TO WS-OB-FILE-PATH`) is a real technique we use in batch processing.

**The anti-pattern sidecar is brilliant:**
- `PAYROLL.cob` with `GO TO` and `ALTER` — I haven't seen ALTER in the wild since 1998, but it's real. JRK's spaghetti code reads like something from our legacy payroll system.
- `TAXCALC.cob` with 6-level nested IFs — painfully authentic. I've debugged worse.
- The fictional developer history (JRK 1974, PMR 1983, Y2K team) is exactly how these systems evolve.
- `KNOWN_ISSUES.md` with documented anti-patterns is a teaching masterclass.

**Educational comments:**
- Every `COBOL CONCEPT:` block explains not just what the syntax does, but *why* it exists. The comparison of `SELECT...ASSIGN` to modern dependency injection is exactly the kind of insight that helps modern developers understand COBOL's design philosophy.

---

## What's Missing / Could Improve

**GnuCOBOL vs z/OS differences need calling out:**
- `ORGANIZATION IS LINE SEQUENTIAL` is a GnuCOBOL extension. On z/OS, we use QSAM with fixed-length records and no line terminators. The code mentions this briefly but should emphasize it more — students will be confused when they hit a real mainframe.
- No JCL examples. In the real world, COBOL programs don't run from a shell — they're submitted as batch jobs with JCL. Even a sample JCL deck would help.

**Missing COBOL patterns:**
- No REDEFINES for variant records (mentioned in SIMREC but not deeply taught)
- No COMPUTE statement examples (uses ADD/SUBTRACT but never `COMPUTE TAX = GROSS * RATE`)
- No INSPECT/TALLY/REPLACING for string manipulation
- No nested programs or CALL for inter-program communication

**The analysis scores are wrong:**
- TRANSACT.cob (labeled "clean") scores 100/spaghetti. As someone who reads COBOL daily, TRANSACT.cob is well-structured code — explicit PERFORMs, no GO TOs, clear paragraph names. The fall-through detection is penalizing normal COBOL paragraph structure. This would confuse students about what "spaghetti" actually means.

**Data validation is thin:**
- No VALIDATE.cob checks for negative balances after withdrawal
- No date validation on ACCT-OPEN-DATE
- Real banking COBOL has extensive field-level validation

---

## WOW Moments

1. **The tamper detection demo.** Changing one byte in BANK_C's data and watching the SHA-256 chain catch it — this is exactly the kind of observability wrapper I wish we had on our z/OS systems. The "COBOL isn't the problem, lack of observability is" narrative resonates deeply.

2. **The compliance detection.** The simulation flagging `SUSPICIOUS_BURST: 8 near-CTR deposits ($9,000-$9,999) — structuring pattern` during a 5-day run. That's real BSA/AML monitoring logic. Whoever wrote this understands banking regulation, not just banking code.

3. **The network graph showing settlement flow.** Being able to *see* money moving between banks through the clearing house hub is something I've wanted to show my junior developers for years.

---

## Deal Breakers

None. The GnuCOBOL limitations are expected for a teaching tool — you can't run z/OS in a GitHub repo.

The analysis scoring bug (BUG-005) should be fixed before showing this to students, as it teaches the wrong lesson about code quality.

---

## Verdict

This is the best COBOL teaching resource I've seen outside of IBM's own training materials. The author clearly understands both COBOL and banking — not just the syntax but the ecosystem. The educational comments are worth the price of admission alone. The settlement system is production-realistic, and the spaghetti payroll sidecar is a masterful teaching device.

I would use this to onboard junior developers joining our mainframe team. The Python observation layer is a smart bridge — it lets modern developers interact with COBOL through tools they already know (REST APIs, SQLite, SHA-256) without pretending COBOL needs to be "modernized."

**Would I recommend this to my team?** Yes. Immediately.
