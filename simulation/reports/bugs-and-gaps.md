# Bugs & Gaps Found During UX Walkthrough

**Date**: 2026-02-28
**Tester**: Playwright-driven UX walkthrough (first-time senior developer perspective)
**Server**: FastAPI on localhost:8000, Ollama qwen2.5:3b for chat

---

## Critical Bugs

### BUG-001: Node popup permission error for `operator` role
- **Severity**: High
- **Location**: `console/js/network-graph.js` → node click handler
- **API**: `GET /api/nodes/BANK_A/chain/verify`
- **Symptom**: Clicking any bank node in the network graph while role=`operator` shows red error text: "User operator (role: operator) lacks permission: chain.verify"
- **Expected**: Operator should be able to view node details (accounts + chain status), or the popup should degrade gracefully by showing accounts without chain verification
- **Impact**: First interaction a user tries (clicking a node) fails unless they switch to admin. Bad first impression.
- **Fix**: Either grant `chain.verify` to operator role in `python/auth.py`, or catch the 403 in the popup JS and show accounts without chain status

### BUG-002: PAYROLL.cob 404 in Analysis tab
- **Severity**: High
- **Location**: `console/js/analysis.js` → file loading logic
- **API**: `GET /cobol-source/payroll/PAYROLL.cob` and `GET /cobol-source/PAYROLL.cob`
- **Symptom**: Selecting any payroll file (PAYROLL.cob, TAXCALC.cob, DEDUCTN.cob, PAYBATCH.cob) and clicking Analyze shows toast "Failed to load PAYROLL.cob: 404". Compare Spaghetti vs Clean also fails.
- **Expected**: Payroll files should load from `COBOL-BANKING/payroll/src/` directory
- **Impact**: The entire spaghetti COBOL analysis feature (a key differentiator) is broken. Analysis only works for clean banking files.
- **Fix**: Update the static file mount in `python/api/app.py` to serve payroll source files, or update the JS to use the correct API endpoint path

### BUG-003: Ollama chat JSON marshaling error
- **Severity**: High
- **Location**: `python/llm/providers.py` → Ollama provider
- **API**: `POST /api/chat` → 502 Bad Gateway
- **Symptom**: Sending any message returns: `Ollama error (qwen2.5:3b): {"error":"json: cannot unmarshal array into Go struct field ChatRequest.messages.content of type string"}`
- **Expected**: Chat should work with Ollama provider and show tool-use cards
- **Impact**: Chat tab is completely non-functional with Ollama. Anthropic provider untested (requires API key).
- **Fix**: The provider is likely sending `content` as an array (OpenAI format) instead of a string (Ollama native format). Fix message serialization in the Ollama provider.

---

## Medium Bugs

### BUG-004: Missing favicon.ico
- **Severity**: Low-Medium
- **Location**: Server static file configuration
- **Symptom**: Console error: `Failed to load resource: 404 (Not Found) @ http://localhost:8000/favicon.ico`
- **Impact**: Browser tab shows generic icon. Minor but looks unprofessional.
- **Fix**: Add a favicon.ico to the static files directory

### BUG-005: TRANSACT.cob rated "spaghetti" score 100
- **Severity**: Medium
- **Location**: `python/cobol_analyzer/complexity.py` or scoring logic
- **Symptom**: TRANSACT.cob (labeled "clean" in the dropdown) receives a spaghetti rating with score 100. The call graph shows many fall-through edges contributing to the high score.
- **Expected**: Clean files should score lower than actual spaghetti files. The fall-through detection may be too aggressive — COBOL paragraphs naturally fall through, but structured code with explicit PERFORMs shouldn't be penalized equally.
- **Impact**: Undermines the spaghetti vs clean comparison narrative if "clean" code also scores as spaghetti.
- **Fix**: Review the fall-through scoring algorithm. Clean COBOL with STOP RUN termination shouldn't have fall-through count toward spaghetti score.

### BUG-006: Chain status shows "BROKEN" on fresh seed
- **Severity**: Low-Medium
- **Location**: Chain verification logic
- **Symptom**: After `seed-all`, clicking a bank node (as admin) shows "Chain: 1 entries, BROKEN (53.6ms)"
- **Expected**: A freshly seeded chain with 1 entry should be VALID
- **Impact**: Confusing for first-time users. Makes integrity system look broken before any tampering.

---

## UX Gaps

### GAP-001: Mobile responsiveness
- **Severity**: Low (desktop-first is fine for teaching tool)
- **Symptom**: At 375px width, nav tabs overflow, role selector hidden, Tamper/Verify buttons cut off
- **Recommendation**: Add `overflow-x: auto` to nav, or collapse to hamburger menu at narrow widths

### GAP-002: No loading indicator for simulation
- **Severity**: Low
- **Symptom**: 5-day simulation completes nearly instantly, making it hard to observe the animation. No spinner or progress bar during computation.
- **Recommendation**: Consider adding artificial delays between days to showcase the network graph animations

### GAP-003: Event feed lacks color coding
- **Severity**: Low
- **Symptom**: All events are the same color except VERIFY_FAIL (red). Transfers, deposits, withdrawals all look identical.
- **Recommendation**: Color-code by event type (green=deposit, red=withdrawal, blue=transfer, yellow=compliance warning)

### GAP-004: Execution trace is minimal
- **Severity**: Low
- **Symptom**: Selecting MAIN-PROGRAM in trace shows only one node with "execution ends (STOP RUN or EXIT)". Doesn't show the full call chain.
- **Expected**: Trace should show MAIN-PROGRAM → PROCESS-DEPOSIT → LOAD-ALL-ACCOUNTS → FIND-ACCOUNT etc.

### GAP-005: No session persistence in chat
- **Severity**: Low
- **Symptom**: After the Ollama error, the session list still shows "No sessions yet" — failed messages don't create sessions

---

## What Works Well

- **Onboarding popup**: Clear, concise, well-designed with role/dashboard/chat instructions
- **Network graph**: Beautiful SVG hub-and-spoke, 6 nodes rendered correctly with bank types
- **COBOL viewer**: All 10 source files load correctly with syntax highlighting and COBOL CONCEPT blocks
- **Simulation engine**: 266 transactions across 5 days with settlement, compliance warnings, and suspicious burst detection
- **Tamper/Verify flow**: Toast notifications work, event feed updates correctly, red VERIFY_FAIL is prominent
- **RBAC enforcement**: Permission denied toast with helpful guidance ("select operator or admin")
- **Glass morphism aesthetic**: Consistent dark theme with frosted glass cards, well-executed throughout
- **Stats bar**: Day counter, OK/Fail counts, volume — updates in real-time during simulation
- **Analysis call graph**: When working (with clean files), the SVG visualization is impressive with color-coded complexity
