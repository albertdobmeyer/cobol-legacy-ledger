# Priority Fixes — Triangulated from 3 Persona Reviews

**Cross-referenced**: Marcus Chen (COBOL maintainer), Sarah Williams (hiring manager), Dev Patel (tech journalist)

---

## P0 — Critical (flagged by all 3 reviewers)

### FIX-001: Payroll files 404 in Analysis tab
- **Bug**: BUG-002
- **Marcus**: "The analysis tab partially fails — payroll files return 404"
- **Sarah**: "The spaghetti examples — the whole point — return 404"
- **Dev**: "If the analysis tab 404s on the spaghetti files, that undermines the feature-complete claim"
- **File**: `python/api/app.py` (static mount) + `console/js/analysis.js` (file path logic)
- **Fix**: Add a static mount for `COBOL-BANKING/payroll/src/` at `/cobol-source/payroll/` or update the JS to use the analysis API endpoint (`/api/analysis/source/{filename}`) which already handles path resolution
- **Effort**: ~30 min

### FIX-002: Ollama chat JSON marshaling error
- **Bug**: BUG-003
- **Marcus**: (N/A — not his domain)
- **Sarah**: "A broken demo is worse than no demo. Fix it or remove it."
- **Dev**: "The chat tab shows a JSON error — undermines feature-complete claim"
- **File**: `python/llm/providers.py` → `OllamaProvider.chat()`
- **Fix**: Ensure message `content` is sent as a string, not an array. Ollama's API expects `{"role": "user", "content": "text"}` not `{"role": "user", "content": [{"type": "text", "text": "..."}]}`
- **Effort**: ~1 hour

### FIX-003: Embed screenshots in README
- **Marcus**: (implied — documentation quality matters)
- **Sarah**: "Show the CI badge. Green badge = instant credibility."
- **Dev**: "I need screenshots in the README itself. Can't feature a repo I can't screenshot without cloning."
- **File**: `README.md`
- **Fix**: Embed `docs/screenshots/dashboard.png`, `docs/screenshots/analysis.png`, `docs/screenshots/chat.png` as inline images. Add CI badge.
- **Effort**: ~15 min

---

## P1 — Important (flagged by 2 reviewers)

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

---

## Implementation Order

**Sprint 1 (2-3 hours):** FIX-001, FIX-002, FIX-003, FIX-004, FIX-012
→ Fixes all broken features + adds README screenshots + favicon

**Sprint 2 (3-4 hours):** FIX-005, FIX-006, FIX-011
→ Fixes scoring algorithm + chain verification + event feed polish

**Sprint 3 (4-6 hours):** FIX-007, FIX-010, FIX-008
→ Docker, demo video, blog post for reach/community

---

## Summary

| Priority | Count | Total Effort |
|----------|-------|-------------|
| P0 (Critical) | 3 | ~2 hours |
| P1 (Important) | 3 | ~3 hours |
| P2 (Nice-to-have) | 6 | ~9 hours |
| **Total** | **12** | **~14 hours** |

The P0 fixes alone would transform this from "impressive but broken" to "impressive and polished." Sprint 1 should be done before sharing the repo publicly.
