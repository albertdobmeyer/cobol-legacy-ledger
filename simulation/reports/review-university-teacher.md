# Dr. Elena Vasquez — Associate Professor of Information Systems, University of Illinois at Chicago

**Teaches IS 447 "Legacy Systems & Modernization" — evaluating this as a semester resource for 30 juniors/seniors**

## Rating: 4.1 / 5 stars

---

## First Impressions

I've been teaching legacy systems for nine years, and every semester I fight the same battle: finding teaching materials that are authentic without being inaccessible. Most COBOL resources are either IBM mainframe manuals (too dense, too z/OS-specific) or toy programs that compile but teach nothing about real-world systems. This project sits in a sweet spot I didn't think existed.

The `COBOL CONCEPT:` blocks caught my eye within 30 seconds. These are ready-made lecture annotations — I could project `ACCOUNTS.cob` on screen and the inline comments do half my teaching for me. The analogy comparing `SELECT...ASSIGN` to dependency injection is exactly how I'd explain it to students who only know Spring Boot.

---

## What Works

**Curriculum-ready structure:**
- The Learning Path (`docs/LEARNING_PATH.md`) maps almost directly onto a 15-week semester. SMOKETEST → ACCOUNTS → TRANSACT → SETTLE builds complexity gradually — that's Bloom's taxonomy in action without labeling it as such.
- The Teaching Guide (`docs/TEACHING_GUIDE.md`) has 8 structured lessons. I could adapt 6 of them directly into my syllabus. The progression from "read a copybook" to "trace a settlement flow" follows sound pedagogical scaffolding.
- The glossary (`docs/GLOSSARY.md`) bridges three vocabularies — COBOL, banking, and modern development. My students struggle most with domain terminology, not syntax. This glossary solves that.

**Progressive disclosure done right:**
- `SMOKETEST.cob` as the entry point is inspired. Four COBOL divisions, no file I/O, no business logic — just "here's how COBOL is structured." I would assign this as Day 1 homework.
- The jump from SMOKETEST to ACCOUNTS introduces file I/O and copybooks. From ACCOUNTS to TRANSACT adds transaction types and batch processing. Each program layers one new concept. That's how learning works.

**The anti-pattern sidecar is a pedagogical masterpiece:**
- I've tried teaching code quality with contrived examples for years. The payroll sidecar with its fictional developer history (JRK 1974, PMR 1983, Y2K team) gives students a *narrative* for why code degrades. It's not "here's bad code" — it's "here's how four decades of maintenance decisions create bad code."
- The compare viewer (spaghetti vs clean side-by-side) is exactly the exercise I assign manually with printouts. Having it built into the web console saves me prep time.

**Testing as a teaching artifact:**
- 519+ tests across 24 files. I can point at this and say "this is what professional testing discipline looks like." The test names are descriptive enough that students can read them as specifications.
- Mode B (Python-only, no COBOL compiler) means students can run tests on their laptops without installing GnuCOBOL. That removes my biggest lab setup headache.

**Distributed systems concepts embedded naturally:**
- The 6-node architecture with per-node databases teaches distributed computing without a single mention of CAP theorem. Students see *why* reconciliation exists by watching settlement move money between independent banks. That experiential understanding sticks better than any lecture slide.

---

## What's Missing / Could Improve

**Lab deployment is too manual:**
- My IT department provisions 30 identical lab machines each semester. Right now, setup means: install Python 3.10+, create a venv, pip install dependencies, optionally install GnuCOBOL, run seed.sh. That's 5 steps where students can fail. I need a single `make lab-setup` or a Docker image I can push to all machines.
- The Ollama dependency for the chat feature adds another installation. My IT department will not install a local LLM runtime on lab machines for a single course. The chat feature is effectively inaccessible to my students.

**No assessment materials:**
- The Teaching Guide has lesson plans but no quiz questions, assignment rubrics, or grading criteria. I would need to write all assessment materials from scratch. Pre-built exercises with expected outputs ("modify ACCOUNTS.cob to add a FREEZE operation — here's the test that should pass") would save instructors significant prep time.
- No checkpoint data snapshots. If a student corrupts their data directory during a lab exercise, they need to re-seed from scratch. Mid-lesson recovery checkpoints (e.g., "restore to state after Lesson 3") would prevent 10-minute delays while 30 students re-run seed.sh.

**Broken demo paths undermine classroom use:**
- The payroll analysis 404 (BUG-002) means I can't demo the spaghetti comparison in class. That's the single most valuable teaching moment in the entire project — showing students what real legacy code looks like and how analysis tools diagnose it.
- The chat JSON error (BUG-003) breaks my planned Week 8 lesson on "using LLMs to understand legacy code." If the chatbot doesn't work, I lose an entire class session's worth of material.

**The TRANSACT spaghetti score teaches the wrong lesson:**
- If students see clean, well-structured COBOL scoring 100 on a "spaghetti index," they'll internalize an incorrect definition of code quality. In a teaching context, this isn't just a bug — it's a pedagogical hazard. Students trust tools implicitly. A wrong score from an authoritative-looking analysis tool will be harder to un-teach than a missing feature.

**The chatbot teaches answers, not understanding:**
- The LLM chat gives direct answers when students ask questions. In a classroom, that's counterproductive — students copy the chatbot's response instead of reasoning through the problem. What I need is a Socratic tutoring mode (similar to EdX's DuckDebugger AI) where the chatbot asks leading questions, provides hints, and guides students toward the answer without simply giving it. "What do you think happens when the nostro balance is insufficient?" is pedagogically superior to a three-paragraph explanation. A toggle between "direct answer" and "tutor mode" would transform this from a reference tool into a learning tool.

**Missing accessibility considerations:**
- No mention of screen reader compatibility or WCAG compliance for the web console. I have students with visual impairments every semester. The glass-morphism aesthetic with low-contrast text on frosted backgrounds would fail WCAG AA contrast ratios.
- The network graph is SVG-only with no text alternatives. A screen reader user would miss the entire settlement visualization.

---

## WOW Moments

1. **The fictional developer history as a narrative device.** JRK's 1974 spaghetti, PMR's 1983 attempt to add structure on top, the Y2K team's dead code branches — I've never seen anti-patterns taught through storytelling before. My students would remember "JRK's GO TO maze" long after they forget what ALTER does. That's the difference between information and learning.

2. **The tamper detection demo as a live "aha moment."** I can see myself projecting this in class: "Watch — I'm going to change one byte in Bank C's data. Now hit Verify All." The SHA-256 chain catches it instantly. That's a 30-second demonstration of cryptographic integrity that would take me 45 minutes to explain with slides. Worth the entire project.

3. **The compliance detection connecting CS to regulation.** When the simulation flags structuring patterns near the CTR threshold, I can pivot to a 10-minute discussion of BSA/AML requirements. This bridges computer science and business regulation in a way that shows students their code has real-world consequences. That's the kind of cross-disciplinary connection accreditation boards love.

4. **The compare viewer as a visual code review exercise.** Spaghetti on the left, clean refactored version on the right. I would assign this as a lab exercise: "Identify three anti-patterns in the left pane and explain how the right pane fixes them." The tool does the setup; students do the analysis.

---

## Deal Breakers

The TRANSACT spaghetti score (BUG-005) is a genuine deal breaker for classroom use. I cannot show students a tool that labels clean code as spaghetti — it would take weeks to correct that misconception. Fix the scoring algorithm before any instructor adopts this.

The payroll 404 is nearly as critical. Without the spaghetti analysis working, the project's strongest teaching device is inaccessible.

---

## Verdict

This is the closest thing I've found to a drop-in teaching resource for legacy systems education. The `COBOL CONCEPT:` blocks, the progressive Learning Path, the structured Teaching Guide, and the anti-pattern sidecar with its fictional developer history — these aren't afterthoughts. Someone designed this to teach.

What holds it back from a 4.5+ rating is classroom logistics. The setup friction, missing assessment materials, broken demo paths, and the spaghetti scoring bug all add prep time that instructors don't have. I would spend roughly 8-10 hours adapting this for my IS 447 syllabus — writing quizzes, creating rubrics, building checkpoint snapshots, and working around the broken features. That's acceptable for a free resource, but it's the gap between "excellent reference material" and "turnkey course module."

**Would I use this in my class?** Yes — selectively. The COBOL source files with educational comments would be assigned reading. The settlement demo would be a live classroom exercise. The spaghetti comparison (once fixed) would be a graded lab. But I'd skip the chat feature entirely and supplement with my own assessment materials.

**What would make this a 5-star teaching resource:**
1. Fix the scoring algorithm and payroll 404
2. Add a `make lab-setup` script or Docker image for computer lab deployment
3. Include 2-3 assignment templates with rubrics and expected outputs
4. Add checkpoint data snapshots for mid-lesson recovery
5. Add a Socratic tutoring mode to the chatbot (hints and guiding questions, not direct answers)
6. Run a WCAG contrast audit on the web console
