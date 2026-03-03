# Improvement Plan — From 4.15★ to 4.9★

**Derived from**: 4-persona simulation analysis + mutant COBOL benchmark goals
**Philosophy**: The WOW factor is proving our tools can tame code that takes humans weeks to understand.

---

## Phase 1: Stop the Bleeding (4 hours → 4.15★ to 4.45★)

*Goal: Every demo path works end-to-end. No broken features.*

### 1A. Fix Payroll 404 (FIX-001) — 30 min
- **File**: `python/api/app.py` + `console/js/analysis.js`
- **Action**: Add static mount for `COBOL-BANKING/payroll/src/` OR update JS to use `/api/analysis/source/{filename}` which already resolves paths
- **Validates**: Spaghetti compare viewer works, call graph loads payroll files, analysis tab fully functional

### 1B. Fix Ollama Chat JSON (FIX-002) — 1 hour
- **File**: `python/llm/providers.py` → `OllamaProvider.chat()`
- **Action**: Ensure `content` is sent as string not array. Ollama expects `{"content": "text"}` not `{"content": [{"type": "text", "text": "..."}]}`
- **Validates**: Chat tab sends/receives messages, tool-use loop works

### 1C. Fix TRANSACT Spaghetti Score (FIX-005) — 2 hours
- **File**: `python/cobol_analyzer/complexity.py`
- **Action**: Don't count FALL_THROUGH edges after STOP RUN paragraphs. Clean COBOL with explicit PERFORMs + STOP RUN should score <20 ("clean").
- **Validates**: TRANSACT.cob scores "clean", PAYROLL.cob scores "spaghetti", compare viewer shows meaningful contrast
- **Why now**: 3 of 4 reviewers flagged this. Teacher calls it a "pedagogical hazard."

### 1D. Fix Chain BROKEN on Fresh Seed (FIX-006) — 30 min
- **File**: `python/integrity.py`
- **Action**: Single-entry chain (genesis block) should verify as VALID
- **Validates**: Fresh seed → node popup shows green VALID, not red BROKEN

---

## Phase 2: Polish the Package (3 hours → 4.45★ to 4.60★)

*Goal: The project looks as good as it is. First impressions match substance.*

### 2A. Embed Screenshots in README (FIX-003) — 30 min
- **File**: `README.md`
- **Action**: Embed 3-4 screenshots inline (dashboard, tamper detection, call graph, compare viewer). Add CI badge.
- **Source**: `simulation/screenshots/` or `docs/screenshots/`

### 2B. Fix Node Popup for Operator Role (FIX-004) — 30 min
- **File**: `python/auth.py` or `console/js/network-graph.js`
- **Action**: Grant `chain.verify` to operator, OR show accounts without chain status when permission denied
- **Validates**: First click on any bank node works for default role

### 2C. Color-Code Event Feed (FIX-011) — 30 min
- **Files**: `console/js/dashboard.js` + `console/css/dashboard.css`
- **Action**: Color events by type (DEPOSIT=green, WITHDRAW=amber, TRANSFER=blue, SETTLEMENT=purple, VERIFY_FAIL=red)

### 2D. Add Favicon (FIX-012) — 15 min
- **File**: `console/favicon.ico` + static mount in `python/api/app.py`

### 2E. Commit Pending Changes — 15 min
- 9 modified files in git status need committing
- Clean working tree signals professionalism

---

## Phase 3: Amplify the Mutant (12 hours → 4.60★ to 4.80★)

*Goal: Make the spaghetti genuinely terrifying. Scale from "weekend project" to "archaeological dig."*

### 3A. Expand Payroll Sidecar to 8 Files (8 hours)

Add 4 new COBOL programs to `COBOL-BANKING/payroll/src/`, each from a different fictional developer era:

| File | Era | Developer | Anti-Patterns | Purpose |
|------|-----|-----------|---------------|---------|
| `EMPMAINT.cob` | 1978, TKN | CALL chains with shared WORKING-STORAGE, COPY REPLACING, implicit scope terminators | Employee master file maintenance — ADD/UPDATE/TERMINATE with audit trail |
| `TIMECARD.cob` | 1986, RBJ | SORT with INPUT/OUTPUT PROCEDURE, nested PERFORM VARYING, GO TO DEPENDING ON | Weekly timecard processing — reads timecards, validates hours, feeds PAYROLL |
| `BENEFITS.cob` | 1994, ACS | Report Writer (RD) dead code, EVALUATE TRUE nesting, STRING/UNSTRING for parsing | Benefits enrollment — open enrollment processing with plan codes |
| `GARNISH.cob` | 2008, KMW + offshore team | Contradicting fixes (two developers "fix" same bug differently), INSPECT TALLYING, excessive COPY nesting (3 levels) | Garnishment/child support — court-ordered deductions with priority rules |

**New copybooks** (in `COBOL-BANKING/payroll/copybooks/`):

| File | Purpose | Teaching Point |
|------|---------|----------------|
| `TIMEREC.cpy` | Timecard record layout | OCCURS DEPENDING ON |
| `BENEREC.cpy` | Benefits election record | REDEFINES for variant records |
| `GARNREC.cpy` | Garnishment order record | Nested COPY (copies EMPREC internally) |

**Developer history update** (`COBOL-BANKING/payroll/README.md`):
- TKN (Thomas K. Nguyen, 1978) — Mainframe purist, CALL-based architecture
- RBJ (Robert "Bobby" Johnson, 1986) — Performance optimizer, SORT tricks
- ACS (Angela Chen-Stevenson, 1994) — Tried to modernize, gave up mid-refactor
- KMW (offshore team, 2008) — Multiple developers, contradicting fixes, copy-paste patterns

**KNOWN_ISSUES.md expansion**: Add EM/TC/BN/GN issue code families (~20 new anti-patterns)

### 3B. Update Complexity Scoring for New Patterns (2 hours)
- **File**: `python/cobol_analyzer/complexity.py`
- **Action**: Add scoring weights for:
  - CALL statement: +2 per occurrence
  - COPY REPLACING: +4 (namespace collision risk)
  - SORT with INPUT/OUTPUT PROCEDURE: +6 (callback-style control flow)
  - GO TO DEPENDING ON: +7 (computed branch)
  - Nested COPY: +5 per level
  - INSPECT TALLYING: +1 (string processing complexity)
  - Contradicting fixes (duplicate paragraph names with different logic): +10

### 3C. Update PayrollBridge for New Files (2 hours)
- **File**: `python/payroll_bridge.py`
- **Action**: Add Mode A/B support for EMPMAINT, TIMECARD, BENEFITS, GARNISH
- **Tests**: Add tests in `python/tests/test_payroll_bridge.py`

---

## Phase 4: Supercharge the Tools (8 hours → 4.80★ to 4.90★)

*Goal: The tools don't just analyze spaghetti — they tame it visibly, impressively, undeniably.*

### 4A. Cross-File Analysis (4 hours)
- **Files**: `python/cobol_analyzer/call_graph.py`, new `python/cobol_analyzer/cross_file.py`
- **Action**: Build a multi-file call graph that traces CALL/COPY chains across programs. Input: list of .cob files. Output: unified graph showing PAYROLL → TAXCALC → DEDUCTN → EMPMAINT → TIMECARD → BENEFITS → GARNISH relationships.
- **API**: New endpoint `POST /api/analysis/cross-file` accepting file list
- **LLM tool**: New `analyze_cross_file` tool
- **Console**: Update call graph SVG to show multi-file nodes (different colors per file)

### 4B. "Human vs AI" Timer Display (1 hour)
- **File**: `console/js/analysis.js` + `console/css/analysis.css`
- **Action**: After analysis completes, show: "Analysis completed in 47ms. Estimated human read time: 3-5 days." Calculate human estimate from line count + complexity score (research: ~50 LOC/hour for spaghetti COBOL).
- **Impact**: Makes the tool's value viscerally obvious.

### 4C. Socratic Tutor Mode (FIX-016) (2 hours)
- **Files**: `python/llm/conversation.py`, `console/js/chat.js`
- **Action**: Add "Tutor Mode" toggle in chat UI. When active, prepend system prompt:
  ```
  You are a Socratic COBOL tutor. Never give direct answers. Instead:
  1. Ask what the student thinks the code does
  2. Point them to the relevant COBOL CONCEPT block
  3. Ask leading questions ("What happens when WS-FILE-STATUS is not '00'?")
  4. Give hints, not solutions
  5. Celebrate when they figure it out
  ```
- **Validates**: Teacher persona gets their DuckDebugger-style learning tool

### 4D. "Explain This Paragraph" LLM Tool (1 hour)
- **Files**: `python/llm/tools.py`, `python/llm/tool_executor.py`
- **Action**: New tool `explain_paragraph` — takes filename + paragraph name, returns:
  1. Plain-English explanation of what it does
  2. Control flow (what it calls, what calls it)
  3. Known issues from KNOWN_ISSUES.md
  4. Complexity score for just this paragraph
- **Impact**: The chatbot becomes genuinely useful for understanding spaghetti

---

## Phase 5: Classroom & Community (6 hours → polish + reach)

*Goal: Remove adoption friction for educators and increase discoverability.*

### 5A. Lab Setup Script (FIX-013) (1 hour)
- **File**: New `Makefile` with targets: `lab-setup`, `lab-reset`, `checkpoint-save`, `checkpoint-restore`
- **Action**: Single `make lab-setup` creates venv, installs deps, compiles COBOL (if available), seeds data, runs smoke test

### 5B. Checkpoint Snapshots (FIX-015) (1 hour)
- **File**: New `scripts/checkpoint.sh`
- **Action**: `make checkpoint-save LESSON=3` snapshots all 6 data directories. `make checkpoint-restore LESSON=3` restores them. Store in `COBOL-BANKING/data/.checkpoints/` (gitignored).

### 5C. Assignment Templates (FIX-014) (2 hours)
- **File**: New `docs/ASSESSMENTS.md`
- **Action**: 3 graded assignments with rubrics:
  1. **Lab 1** (Lesson 3): Add FREEZE account status to ACCOUNTS.cob. Rubric: FILE STATUS handling, 88-level condition, test passes.
  2. **Lab 2** (Lesson 7): Trace PAYROLL.cob's ALTER chain manually, compare with analyzer output. Rubric: correct trace, identified dead paragraphs.
  3. **Lab 3** (Lesson 9): Write a KNOWN_ISSUES entry for a new anti-pattern you discover in BENEFITS.cob. Rubric: issue code, era, risk assessment, modern equivalent.

### 5D. Docker Compose (FIX-007) (1 hour)
- **Files**: New `Dockerfile`, `docker-compose.yml`
- **Action**: Single `docker compose up` for demo reviewers. Includes GnuCOBOL + Python + seed data.

### 5E. Companion Content (FIX-008, FIX-010) (1 hour)
- Record 30-second GIF of: start simulation → watch network graph → tamper → detect
- Outline blog post: "I Built a COBOL Banking System to Prove Legacy Code Isn't the Problem"

---

## Implementation Timeline

| Phase | Hours | Cumulative | Rating |
|-------|-------|-----------|--------|
| Phase 1: Stop the Bleeding | 4h | 4h | 4.45★ |
| Phase 2: Polish the Package | 3h | 7h | 4.60★ |
| Phase 3: Amplify the Mutant | 12h | 19h | 4.80★ |
| Phase 4: Supercharge the Tools | 8h | 27h | 4.90★ |
| Phase 5: Classroom & Community | 6h | 33h | 4.90★+ |
| **Total** | **33h** | | **4.90★** |

---

## Priority Order (If Time-Constrained)

**If you have 4 hours**: Phase 1 only. Fix the broken demos. Biggest ROI.

**If you have 7 hours**: Phase 1 + 2. Working + polished. Ready for sharing.

**If you have 20 hours**: Phase 1 + 2 + 3. The mutant COBOL expansion is the project's soul — 8 spaghetti files instead of 4 transforms it from "teaching tool" to "archaeological simulation." This is where the WOW factor lives.

**If you have 33 hours**: All 5 phases. The tools taming the mutant code, the Socratic tutor mode, the cross-file analysis, the "Human vs AI" timer — this is the full vision. A 4.9★ portfolio project that no competing resource can match.

---

## Success Criteria

The project achieves its full potential when a viewer can:

1. **See** the spaghetti (8 files, 50+ years, 8 developers, 3000+ lines of authentic mutant COBOL)
2. **Watch** the tools tame it (cross-file call graph, ALTER chain tracing, dead code detection — all in <100ms)
3. **Feel** the contrast (Human: 3-5 days. AI: 47ms. Displayed on screen.)
4. **Try** it themselves (Socratic tutor guides them through understanding, doesn't give answers)
5. **Trust** it works (519+ tests, tamper detection, SHA-256 chains, every demo path functional)

That's a 4.9★ project. That's the WOW factor.
