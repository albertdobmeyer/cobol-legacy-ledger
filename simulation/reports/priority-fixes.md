# Priority Fixes — Triangulated from 4 Persona Reviews

**Cross-referenced**: Marcus Chen (COBOL maintainer), Sarah Williams (hiring manager), Dev Patel (tech journalist), Dr. Elena Vasquez (university teacher)

---

## P0 — Critical (flagged by 3-4 reviewers)

### FIX-001: Payroll files 404 in Analysis tab
- **Bug**: BUG-002
- **Marcus**: "The analysis tab partially fails — payroll files return 404"
- **Sarah**: "The spaghetti examples — the whole point — return 404"
- **Dev**: "If the analysis tab 404s on the spaghetti files, that undermines the feature-complete claim"
- **Dr. Vasquez**: "The spaghetti comparison is the single most valuable teaching moment — and it's inaccessible"
- **File**: `python/api/app.py` (static mount) + `console/js/analysis.js` (file path logic)
- **Fix**: Add a static mount for `COBOL-BANKING/payroll/src/` at `/cobol-source/payroll/` or update the JS to use the analysis API endpoint (`/api/analysis/source/{filename}`) which already handles path resolution
- **Effort**: ~30 min

### FIX-002: Ollama chat JSON marshaling error
- **Bug**: BUG-003
- **Marcus**: (N/A — not his domain)
- **Sarah**: "A broken demo is worse than no demo. Fix it or remove it."
- **Dev**: "The chat tab shows a JSON error — undermines feature-complete claim"
- **Dr. Vasquez**: "Breaks my planned Week 8 lesson on using LLMs to understand legacy code"
- **File**: `python/llm/providers.py` → `OllamaProvider.chat()`
- **Fix**: Ensure message `content` is sent as a string, not an array. Ollama's API expects `{"role": "user", "content": "text"}` not `{"role": "user", "content": [{"type": "text", "text": "..."}]}`
- **Effort**: ~1 hour

### FIX-003: Embed screenshots in README
- **Marcus**: (implied — documentation quality matters)
- **Sarah**: "Show the CI badge. Green badge = instant credibility."
- **Dev**: "I need screenshots in the README itself. Can't feature a repo I can't screenshot without cloning."
- **Dr. Vasquez**: (less concerned — runs it live in class)
- **File**: `README.md`
- **Fix**: Embed `docs/screenshots/dashboard.png`, `docs/screenshots/analysis.png`, `docs/screenshots/chat.png` as inline images. Add CI badge.
- **Effort**: ~15 min

---

## P1 — Important (flagged by 2-4 reviewers)

### FIX-004: Node popup fails for operator role
- **Bug**: BUG-001
- **Marcus**: (would expect it to work)
- **Sarah**: "First interaction fails unless they switch to admin. Bad first impression."
- **Dev**: (would hit this during demo)
- **File**: `python/auth.py` → RBAC permissions, or `console/js/network-graph.js` → graceful degradation
- **Fix**: Grant `chain.verify` to operator, OR show accounts without chain status when permission denied
- **Effort**: ~30 min

### FIX-005: TRANSACT.cob "spaghetti" score 100
- **Bug**: BUG-005
- **Marcus**: "TRANSACT.cob is well-structured code. The fall-through detection is penalizing normal COBOL paragraph structure."
- **Sarah**: (confusing for candidate's narrative)
- **Dev**: (undermines clean vs spaghetti comparison)
- **Dr. Vasquez**: "Students trust tools implicitly. A wrong score is a pedagogical hazard — harder to un-teach than a missing feature"
- **File**: `python/cobol_analyzer/complexity.py`
- **Fix**: Don't count fall-through edges after STOP RUN paragraphs. Clean COBOL with explicit PERFORMs + STOP RUN termination should not be penalized for paragraph adjacency.
- **Effort**: ~2 hours

### FIX-006: Chain shows "BROKEN" on fresh seed
- **Bug**: BUG-006
- **Marcus**: "A freshly seeded chain with 1 entry should be VALID"
- **Sarah**: "Confusing for first-time users"
- **File**: `python/integrity.py` → chain verification logic
- **Fix**: Single-entry chain should verify as VALID (genesis block)
- **Effort**: ~30 min

---

## P2 — Nice-to-Have (flagged by 1 reviewer)

### FIX-007: Add Docker Compose for one-click demo
- **Sarah**: "A single `make demo` or Docker Compose would lower the barrier for reviewers"
- **File**: New `docker-compose.yml` + `Dockerfile`
- **Effort**: ~2 hours

### FIX-008: Write companion blog post
- **Dev**: "A blog post explaining the project would make it 5x more linkable"
- **Format**: "I Built a COBOL Banking System to Prove Legacy Code Isn't the Problem"
- **Effort**: ~4 hours

### FIX-009: Add JCL examples for z/OS context
- **Marcus**: "No JCL examples. Even a sample JCL deck would help."
- **File**: New `docs/JCL_EXAMPLES.md`
- **Effort**: ~1 hour

### FIX-010: Create 30-second demo GIF/video
- **Dev**: "A GitHub Pages site or 30-second video would 10x the reach"
- **Format**: GIF of simulation running (network graph + event feed + stats)
- **Effort**: ~1 hour

### FIX-011: Color-code event feed by type
- **Walkthrough observation**: All events same color except VERIFY_FAIL
- **File**: `console/js/dashboard.js` + `console/css/dashboard.css`
- **Effort**: ~30 min

### FIX-012: Add missing favicon.ico
- **Bug**: BUG-004
- **File**: `console/favicon.ico` + static mount
- **Effort**: ~15 min

### FIX-013: Add lab deployment script
- **Dr. Vasquez**: "Setup means 5 steps where students can fail. I need a single `make lab-setup`."
- **Sarah**: (echoes Docker Compose request in FIX-007)
- **File**: New `Makefile` or `scripts/lab-setup.sh`
- **Fix**: Single-command setup: create venv, install deps, seed data, verify. Complement FIX-007 (Docker) with a non-Docker alternative for labs that can't run containers.
- **Effort**: ~1 hour

### FIX-014: Add quiz/assignment templates to Teaching Guide
- **Dr. Vasquez**: "The Teaching Guide has lesson plans but no quiz questions, assignment rubrics, or grading criteria. I'd need to write all assessment materials from scratch."
- **File**: `docs/TEACHING_GUIDE.md` (new appendix) or `docs/ASSESSMENTS.md`
- **Fix**: Add 2-3 assignment templates with rubrics and expected outputs (e.g., "modify ACCOUNTS.cob to add a FREEZE operation — here's the test that should pass"). Include sample quiz questions per lesson.
- **Effort**: ~3 hours

### FIX-015: Add checkpoint data snapshots for mid-lesson recovery
- **Dr. Vasquez**: "If a student corrupts their data during a lab, they re-seed from scratch. 10-minute delays while 30 students re-run seed.sh."
- **File**: New `scripts/checkpoint.sh` + `COBOL-BANKING/data/checkpoints/`
- **Fix**: Provide save/restore commands for data directory state at key lesson boundaries (e.g., after Lesson 3, after first settlement). `make checkpoint-save LESSON=3` / `make checkpoint-restore LESSON=3`.
- **Effort**: ~2 hours

### FIX-016: Add Socratic tutoring mode to LLM chat
- **Dr. Vasquez**: "The chatbot gives direct answers. I need it to guide students toward understanding — ask leading questions, give hints, not solutions. Like EdX's DuckDebugger AI."
- **File**: `python/llm/conversation.py` or `python/llm/providers.py` (system prompt), `console/js/chat.js` (mode toggle)
- **Fix**: Add a "Tutor Mode" toggle in the chat UI. When active, prepend a system prompt instructing the LLM to use Socratic questioning: respond with guiding questions, provide hints before answers, ask "what do you think happens when..." instead of explaining directly. Preserve the existing direct-answer mode as default.
- **Effort**: ~2 hours

---

## Implementation Order

**Sprint 1 (2-3 hours):** FIX-001, FIX-002, FIX-003, FIX-004, FIX-012
→ Fixes all broken features + adds README screenshots + favicon

**Sprint 2 (3-4 hours):** FIX-005, FIX-006, FIX-011
→ Fixes scoring algorithm + chain verification + event feed polish

**Sprint 3 (4-6 hours):** FIX-007, FIX-013, FIX-010, FIX-008
→ Docker, lab setup, demo video, blog post for reach/community

**Sprint 4 (7-8 hours):** FIX-014, FIX-015, FIX-016
→ Teaching materials: assessment templates, checkpoint snapshots, Socratic tutor mode

---

## Summary

| Priority | Count | Total Effort |
|----------|-------|-------------|
| P0 (Critical) | 3 | ~2 hours |
| P1 (Important) | 3 | ~3 hours |
| P2 (Nice-to-have) | 10 | ~17 hours |
| **Total** | **16** | **~22 hours** |

The P0 fixes alone would transform this from "impressive but broken" to "impressive and polished." Sprint 1 should be done before sharing the repo publicly. Sprint 4 targets classroom adoption — the teacher-specific fixes that would make this a turnkey course module.
