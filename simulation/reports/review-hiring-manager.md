# Sarah Williams — VP Engineering / Hiring Manager, Edward Jones

**Evaluates portfolio projects for junior developers entering legacy systems modernization**

## Rating: 4.5 / 5 stars

---

## First Impressions

I review 50+ GitHub portfolio projects per hiring cycle. Most COBOL-related projects fall into two categories: (1) "Hello World" level programs that prove nothing, or (2) massively over-scoped frameworks with more README than code. This project is rare — it's a complete, working system that demonstrates genuine understanding of both the technology and the business domain.

The moment I saw the 6-node architecture with a clearing house, I knew this candidate understands financial systems, not just programming languages. That's the signal I look for.

---

## What Works

**System thinking on display:**
- The "wrap, don't modify" philosophy is exactly the mindset we need. Our biggest challenge isn't writing new COBOL — it's building observability around 40 years of existing COBOL without breaking it.
- The SHA-256 hash chain for tamper detection shows security awareness without over-engineering.
- Per-node databases mirror real distributed banking — this candidate won't be surprised by our architecture.

**Code quality signals:**
- 547 tests (as claimed). That's not a number you pad — it demonstrates testing discipline.
- Production-style file headers on COBOL source — shows attention to conventions.
- Educational comments that explain *why*, not just *what* — this is how you write maintainable code and how you teach junior teammates.
- Consistent error handling with FILE STATUS checks throughout.

**Communication skills:**
- The README tells a clear story. Architecture diagram, quick start, and the "COBOL isn't the problem" thesis hook me immediately.
- The Teaching Guide and Learning Path show this person can structure information for different audiences.
- The glossary bridges COBOL, banking, and modern dev terminology — that's translation skill we desperately need.

**Full-stack capability:**
- COBOL source → Python bridge → FastAPI API → Static HTML/JS console
- This is a vertical slice through a real modernization stack. The candidate built every layer.
- No Node.js dependency — FastAPI serves static files. Shows pragmatism over trendiness.

**The spaghetti payroll sidecar:**
- This is portfolio gold. Instead of just writing clean code, they deliberately created realistic legacy anti-patterns *and* built analysis tools to diagnose them. That shows:
  1. They understand what bad legacy code looks like
  2. They can build tools to understand it
  3. They can teach others about it

---

## What's Missing / Could Improve

**The chat feature is broken:**
- Ollama integration returns a JSON marshaling error. If I were evaluating this in an interview, a broken demo is worse than no demo. Fix it or remove it from the default view.

**The analysis tab partially fails:**
- Payroll files (the spaghetti examples — the whole point!) return 404. This undermines the strongest differentiator.

**No CI/CD badge visible:**
- I see a `.github/workflows/ci.yml` in the git status. If tests pass in CI, show the badge in the README. Green badge = instant credibility.

**Missing "Getting Started" friction reduction:**
- The setup requires understanding Python venvs, COBOL optional compilation, and seeding. A single `make demo` or Docker Compose would lower the barrier for reviewers who have 5 minutes to evaluate.

**No performance numbers:**
- The 5-day simulation ran 266 transactions near-instantly. Impressive but not quantified. "Processes 53 transactions/second across 6 nodes" would be a compelling metric.

---

## WOW Moments

1. **The tamper → verify → detect flow.** In 3 clicks, I watched the system inject fraud and catch it. This is the kind of demo that makes me put down my coffee and pay attention. It's visual, immediate, and proves the integrity system works.

2. **The RBAC enforcement.** Switching to "viewer" and getting a permission-denied toast with helpful guidance ("select operator or admin") shows the candidate thinks about authorization — not just authentication. In financial services, that matters.

3. **The compliance detection in the event feed.** "SUSPICIOUS_BURST: 8 near-CTR deposits ($9,000-$9,999) — structuring pattern" and "LARGE_TRANSFER: $55,000 wire attempted — exceeds $50K daily limit" — this candidate knows BSA/AML. That's domain knowledge you can't teach in a bootcamp.

4. **The network topology visualization.** Seeing 6 nodes with hub-and-spoke settlement in a glass-morphism UI tells me this person can communicate complex systems visually. That's a leadership skill.

---

## Deal Breakers

The broken chat and analysis features (BUG-002, BUG-003) need to be fixed before this goes on a resume. A hiring manager who clicks through the demo and hits errors will question attention to detail.

---

## Verdict

**Would this project make me call a candidate for an interview?** Absolutely yes.

This project demonstrates:
- **Domain knowledge**: Banking, settlement, compliance, COBOL conventions
- **System design**: Distributed architecture, cryptographic integrity, RBAC
- **Engineering discipline**: 547 tests, educational documentation, production headers
- **Communication**: Teaching guide, glossary, clear README narrative
- **Practical modernization skills**: Wrapping legacy systems without modifying them

The candidate who built this would be competitive for a mid-level legacy systems modernization role, not just a junior position. The combination of COBOL literacy, Python competence, and financial domain knowledge is rare.

**My advice to the candidate:** Fix the three broken features (chat, analysis payroll files, chain status on fresh seed), add a Docker Compose for one-click demo, and this is a top-1% portfolio project.

**Interview topics I'd explore:**
1. Walk me through the 3-leg settlement flow — how does money actually move?
2. Why SHA-256 hash chain instead of a simpler integrity check?
3. How would you scale this to handle real-world transaction volumes?
4. Tell me about a time you had to understand legacy code without documentation (the payroll sidecar is the answer).
