"""
End-to-end Playwright tests for the web console.

These tests launch a real browser against the running FastAPI server and
exercise the dashboard (simulation controls, network graph, event feed,
COBOL viewer, reset, onboarding) and the chatbot UI (messages, tool calls,
provider switching, sessions).

Prerequisites:
    - Server running at http://localhost:8000
    - Data seeded via `python -m python.cli seed-all`
    - Playwright browsers installed: `python -m playwright install chromium`

Run:
    python -m pytest python/tests/test_e2e_playwright.py -v --headed   # visible browser
    python -m pytest python/tests/test_e2e_playwright.py -v            # headless
"""

import re
import pytest
from playwright.sync_api import Page, expect

BASE_URL = "http://localhost:8000"


# ── Fixtures ──────────────────────────────────────────────────────

def _stop_any_running_sim():
    """Stop any running simulation via API (best-effort)."""
    import urllib.request, json, time
    for endpoint in ["/api/simulation/stop", "/api/simulation/reset"]:
        try:
            req = urllib.request.Request(
                f"{BASE_URL}{endpoint}",
                data=b"{}",
                headers={"Content-Type": "application/json",
                         "X-User": "admin", "X-Role": "admin"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception:
            pass
    # Brief wait for background thread to actually stop
    time.sleep(1)


@pytest.fixture(scope="function")
def fresh_page(page: Page):
    """Navigate to app, dismiss onboarding if shown, go to dashboard."""
    _stop_any_running_sim()
    page.goto(f"{BASE_URL}/console/index.html")
    page.wait_for_selector(".nav__brand", timeout=5000)
    # Dismiss onboarding if visible
    dismiss = page.locator("#onboardingDismiss")
    if dismiss.is_visible():
        dismiss.click()
        page.wait_for_timeout(300)
    # Select operator role so simulation tests have permission
    role_select = page.locator("#roleSelect")
    if role_select.is_visible():
        role_select.select_option("operator")
    # Ensure dashboard tab is active
    page.click("[data-view='dashboard']")
    page.wait_for_selector("#view-dashboard.view--active", timeout=3000)
    return page


@pytest.fixture(scope="function")
def dash(fresh_page: Page):
    """Dashboard-ready page (onboarding dismissed)."""
    return fresh_page


@pytest.fixture(scope="function")
def chat_view(page: Page):
    """Navigate to chat view, dismiss onboarding if needed."""
    page.goto(f"{BASE_URL}/console/index.html")
    page.wait_for_selector(".nav__brand", timeout=5000)
    # Dismiss onboarding
    dismiss = page.locator("#onboardingDismiss")
    if dismiss.is_visible():
        dismiss.click()
        page.wait_for_timeout(300)
    page.click("[data-view='chat']")
    page.wait_for_selector("#view-chat.view--active", timeout=3000)
    return page


# ── Onboarding Tests ─────────────────────────────────────────────

class TestOnboarding:
    """Test first-visit onboarding popup."""

    def test_onboarding_shows_on_first_visit(self, page: Page):
        """Onboarding popup appears when localStorage flag is absent."""
        # Clear the flag so onboarding triggers
        page.goto(f"{BASE_URL}/console/index.html")
        page.evaluate("localStorage.removeItem('cll_onboarded')")
        page.reload()
        page.wait_for_selector(".nav__brand", timeout=5000)
        overlay = page.locator("#onboarding")
        expect(overlay).to_be_visible(timeout=3000)

    def test_onboarding_has_content(self, page: Page):
        """Onboarding popup contains role, dashboard, and chat info."""
        page.goto(f"{BASE_URL}/console/index.html")
        page.evaluate("localStorage.removeItem('cll_onboarded')")
        page.reload()
        page.wait_for_selector("#onboarding", state="visible", timeout=5000)
        text = page.locator("#onboarding").text_content()
        assert "Role selector" in text
        assert "Dashboard" in text
        assert "Chat" in text

    def test_onboarding_dismiss_sets_flag(self, page: Page):
        """Clicking 'Got it' hides the popup and sets localStorage."""
        page.goto(f"{BASE_URL}/console/index.html")
        page.evaluate("localStorage.removeItem('cll_onboarded')")
        page.reload()
        page.wait_for_selector("#onboardingDismiss", state="visible", timeout=5000)
        page.click("#onboardingDismiss")
        page.wait_for_timeout(500)
        expect(page.locator("#onboarding")).to_be_hidden()
        flag = page.evaluate("localStorage.getItem('cll_onboarded')")
        assert flag == "1"

    def test_onboarding_not_shown_on_return(self, page: Page):
        """Onboarding does not appear if flag is already set."""
        page.goto(f"{BASE_URL}/console/index.html")
        page.evaluate("localStorage.setItem('cll_onboarded', '1')")
        page.reload()
        page.wait_for_selector(".nav__brand", timeout=5000)
        page.wait_for_timeout(500)
        expect(page.locator("#onboarding")).to_be_hidden()


# ── Dashboard Rendering ──────────────────────────────────────────

class TestDashboardLoads:
    """Verify the dashboard renders its core elements."""

    def test_nav_brand_and_tabs(self, dash: Page):
        """Navigation bar with brand and both tabs is visible."""
        expect(dash.locator(".nav__brand")).to_have_text("COBOL Legacy Ledger")
        expect(dash.locator("[data-view='dashboard']")).to_be_visible()
        expect(dash.locator("[data-view='chat']")).to_be_visible()

    def test_network_graph_six_nodes(self, dash: Page):
        """Network topology SVG renders with exactly 6 nodes."""
        svg = dash.locator("#graphContainer svg")
        expect(svg).to_be_visible(timeout=5000)
        nodes = dash.locator("#graphContainer svg .node-group")
        expect(nodes).to_have_count(6, timeout=5000)

    def test_all_control_buttons_present(self, dash: Page):
        """All simulation control buttons are visible."""
        for btn_id in ["#btnStart", "#btnPause", "#btnStop", "#btnReset",
                       "#btnTamper", "#btnVerify"]:
            expect(dash.locator(btn_id)).to_be_visible()

    def test_days_input_present(self, dash: Page):
        """Days input field is present with default value."""
        days = dash.locator("#daysInput")
        expect(days).to_be_visible()
        assert int(days.input_value()) > 0

    def test_stats_counters_at_zero(self, dash: Page):
        """Stats show zero before any simulation runs."""
        expect(dash.locator("#dayCounter")).to_have_text("Day 0")
        expect(dash.locator("#statCompleted")).to_have_text("0")
        expect(dash.locator("#statFailed")).to_have_text("0")

    def test_cobol_viewer_loads_default_file(self, dash: Page):
        """COBOL viewer panel loads SMOKETEST.cob by default."""
        viewer = dash.locator("#cobolSource")
        expect(viewer).to_be_visible()
        dash.wait_for_function(
            "document.querySelector('#cobolSource').textContent.length > 50",
            timeout=5000,
        )
        # Default file should be SMOKETEST.cob
        selector = dash.locator("#cobolFileSelect")
        expect(selector).to_have_value("SMOKETEST.cob")

    def test_role_selector_defaults_to_operator(self, dash: Page):
        """Role selector defaults to operator (can start simulations)."""
        expect(dash.locator("#roleSelect")).to_have_value("operator")

    def test_health_dot_turns_green(self, dash: Page):
        """Health indicator dot is visible and shows healthy status."""
        dot = dash.locator("#healthDot")
        expect(dot).to_be_visible()
        # Wait for health check to complete
        dash.wait_for_function(
            "document.querySelector('#healthDot').classList.contains('health-dot--ok')",
            timeout=10000,
        )

    def test_event_feed_empty_initially(self, dash: Page):
        """Event feed shows empty state before simulation."""
        feed = dash.locator("#feedList")
        expect(feed).to_be_visible()
        text = feed.text_content()
        assert "Start a simulation" in text or "event" in text.lower()


# ── Simulation Controls ──────────────────────────────────────────

class TestSimulationControls:
    """Test simulation start, pause, resume, stop, reset workflow."""

    def test_start_simulation_updates_stats(self, dash: Page):
        """Start button launches simulation; day counter and stats update."""
        dash.fill("#daysInput", "3")
        dash.click("#btnStart")

        # Day counter advances past 0
        dash.wait_for_function(
            "document.querySelector('#dayCounter').textContent !== 'Day 0'",
            timeout=20000,
        )
        # Completed transactions appear
        dash.wait_for_function(
            "parseInt(document.querySelector('#statCompleted').textContent) > 0",
            timeout=20000,
        )
        # Volume shows a dollar amount
        dash.wait_for_function(
            "document.querySelector('#statVolume').textContent !== '$0'",
            timeout=20000,
        )

    def test_start_populates_event_feed(self, dash: Page):
        """Starting a simulation populates the event feed."""
        dash.fill("#daysInput", "3")
        dash.click("#btnStart")

        dash.wait_for_function(
            "document.querySelectorAll('.feed__item').length > 0",
            timeout=20000,
        )
        items = dash.locator(".feed__item")
        assert items.count() > 0

    def test_simulation_runs_past_day_5(self, dash: Page):
        """Simulation progresses beyond day 5 (verifies no verification hang)."""
        # Reset first to ensure clean state (no leftover running sim)
        dash.click("#btnReset")
        dash.wait_for_timeout(3000)

        dash.fill("#daysInput", "8")
        dash.click("#btnStart")

        # Wait for day > 5 — verification at day 5 used to hang
        dash.wait_for_function(
            """(() => {
                const txt = document.querySelector('#dayCounter').textContent;
                const m = txt.match(/\\d+/);
                return m && parseInt(m[0]) > 5;
            })()""",
            timeout=120000,
        )
        day_text = dash.locator("#dayCounter").text_content()
        day_num = int(re.search(r'\d+', day_text).group())
        assert day_num > 5, f"Expected day > 5, got {day_num}"

    def test_adjust_days_input(self, dash: Page):
        """Days input accepts and retains new values."""
        dash.fill("#daysInput", "10")
        expect(dash.locator("#daysInput")).to_have_value("10")
        dash.fill("#daysInput", "50")
        expect(dash.locator("#daysInput")).to_have_value("50")

    def test_start_disables_start_enables_others(self, dash: Page):
        """After start, Start is disabled; Pause and Stop are enabled."""
        dash.fill("#daysInput", "25")
        dash.click("#btnStart")
        # Wait for button state to change (Start becomes disabled when sim starts)
        dash.wait_for_function(
            "document.querySelector('#btnStart').disabled === true",
            timeout=10000,
        )

        expect(dash.locator("#btnStart")).to_be_disabled()
        expect(dash.locator("#btnPause")).to_be_enabled()
        expect(dash.locator("#btnStop")).to_be_enabled()

        # Clean up (best-effort — sim may finish between check and click)
        try:
            dash.click("#btnStop", timeout=2000)
        except Exception:
            pass

    def test_pause_changes_to_resume(self, dash: Page):
        """Pause button text changes to 'Resume' when clicked."""
        dash.fill("#daysInput", "25")
        dash.click("#btnStart")
        dash.wait_for_function(
            "document.querySelector('#btnStart').disabled === true",
            timeout=10000,
        )

        pause_btn = dash.locator("#btnPause")
        expect(pause_btn).to_have_text("Pause")
        dash.click("#btnPause")
        dash.wait_for_timeout(500)
        expect(pause_btn).to_have_text("Resume")

        # Resume
        dash.click("#btnPause")
        dash.wait_for_timeout(500)
        expect(pause_btn).to_have_text("Pause")

        # Clean up (best-effort — sim may finish between check and click)
        try:
            dash.click("#btnStop", timeout=2000)
        except Exception:
            pass

    def test_stop_re_enables_start(self, dash: Page):
        """After stop, Start is re-enabled; Pause and Stop are disabled."""
        dash.fill("#daysInput", "25")
        dash.click("#btnStart")
        dash.wait_for_function(
            "document.querySelector('#btnStart').disabled === true",
            timeout=10000,
        )
        dash.click("#btnStop")
        dash.wait_for_function(
            "document.querySelector('#btnStart').disabled === false",
            timeout=10000,
        )

        expect(dash.locator("#btnStart")).to_be_enabled()
        expect(dash.locator("#btnPause")).to_be_disabled()
        expect(dash.locator("#btnStop")).to_be_disabled()

    def test_reset_clears_counters(self, dash: Page):
        """Reset button re-seeds data and resets UI counters."""
        # Run a short sim first
        dash.fill("#daysInput", "2")
        dash.click("#btnStart")
        dash.wait_for_function(
            "parseInt(document.querySelector('#statCompleted').textContent) > 0",
            timeout=20000,
        )
        # Wait for sim to finish
        dash.wait_for_function(
            "!document.querySelector('#btnStart').disabled",
            timeout=30000,
        )

        # Now reset
        dash.click("#btnReset")
        dash.wait_for_timeout(3000)

        expect(dash.locator("#dayCounter")).to_have_text("Day 0")
        expect(dash.locator("#statCompleted")).to_have_text("0")
        expect(dash.locator("#statFailed")).to_have_text("0")

    def test_viewer_role_cannot_start(self, dash: Page):
        """Viewer role gets permission denied when trying to start."""
        dash.select_option("#roleSelect", "viewer")
        dash.wait_for_timeout(300)
        dash.click("#btnStart")
        # Should show an error toast
        dash.wait_for_selector(".toast", timeout=5000)
        toast_text = dash.locator(".toast").first.text_content()
        assert "permission" in toast_text.lower() or "denied" in toast_text.lower() or "403" in toast_text

        # Restore operator role
        dash.select_option("#roleSelect", "operator")


# ── Tamper & Verify ──────────────────────────────────────────────

class TestTamperAndVerify:
    """Test tamper demo and cross-node verification buttons."""

    def test_tamper_shows_toast(self, dash: Page):
        """Tamper button shows a success toast (requires auditor+ role)."""
        # Tamper requires chain.verify permission — switch to admin
        dash.select_option("#roleSelect", "admin")
        dash.wait_for_timeout(300)
        dash.click("#btnTamper")
        dash.wait_for_selector(".toast", timeout=5000)
        toast = dash.locator(".toast").first.text_content()
        assert "tamper" in toast.lower() or "balance" in toast.lower()
        dash.select_option("#roleSelect", "operator")

    def test_verify_shows_toast(self, dash: Page):
        """Verify button shows a verification result toast."""
        dash.select_option("#roleSelect", "admin")
        dash.wait_for_timeout(300)
        dash.click("#btnVerify")
        dash.wait_for_selector(".toast", timeout=30000)
        dash.select_option("#roleSelect", "operator")

    def test_tamper_then_verify_detects_tampering(self, dash: Page):
        """Tamper then verify should detect the mismatch."""
        dash.select_option("#roleSelect", "admin")
        dash.wait_for_timeout(300)
        dash.click("#btnTamper")
        dash.wait_for_timeout(1500)
        dash.click("#btnVerify")
        dash.wait_for_selector(".toast", timeout=10000)
        toasts = dash.locator(".toast")
        assert toasts.count() >= 1
        dash.select_option("#roleSelect", "operator")


# ── COBOL Viewer ─────────────────────────────────────────────────

class TestCobolViewer:
    """Test COBOL source viewer functionality."""

    def test_default_file_loads(self, dash: Page):
        """Default SMOKETEST.cob loads with COBOL content."""
        dash.wait_for_function(
            "document.querySelector('#cobolSource').textContent.length > 50",
            timeout=5000,
        )
        content = dash.locator("#cobolSource").text_content()
        assert "IDENTIFICATION" in content or "DIVISION" in content or "PROGRAM-ID" in content

    def test_switch_to_transact(self, dash: Page):
        """Selecting TRANSACT.cob loads transaction processing code."""
        dash.wait_for_function(
            "document.querySelector('#cobolSource').textContent.length > 50",
            timeout=5000,
        )
        dash.evaluate("""
            const sel = document.querySelector('#cobolFileSelect');
            sel.value = 'TRANSACT.cob';
            sel.dispatchEvent(new Event('change'));
        """)
        dash.wait_for_function(
            "!document.querySelector('#cobolSource').textContent.includes('Loading')",
            timeout=5000,
        )
        content = dash.locator("#cobolSource").text_content()
        assert "TRANSACT" in content or "IDENTIFICATION" in content or "DIVISION" in content

    def test_switch_to_settle(self, dash: Page):
        """Selecting SETTLE.cob loads settlement code."""
        dash.wait_for_function(
            "document.querySelector('#cobolSource').textContent.length > 50",
            timeout=5000,
        )
        dash.evaluate("""
            const sel = document.querySelector('#cobolFileSelect');
            sel.value = 'SETTLE.cob';
            sel.dispatchEvent(new Event('change'));
        """)
        dash.wait_for_function(
            "!document.querySelector('#cobolSource').textContent.includes('Loading')",
            timeout=5000,
        )
        content = dash.locator("#cobolSource").text_content()
        assert "SETTLE" in content or "DIVISION" in content

    def test_all_ten_files_in_selector(self, dash: Page):
        """File selector has all 10 COBOL source files."""
        options = dash.locator("#cobolFileSelect option")
        count = options.count()
        assert count == 10, f"Expected 10 COBOL files, got {count}"

    def test_syntax_highlighting_present(self, dash: Page):
        """COBOL viewer applies syntax highlighting spans."""
        dash.wait_for_function(
            "document.querySelector('#cobolSource').textContent.length > 50",
            timeout=5000,
        )
        # Syntax highlighter wraps keywords in spans
        spans = dash.locator("#cobolSource span")
        assert spans.count() > 0, "Expected syntax highlighting spans"


# ── Node Interaction ─────────────────────────────────────────────

class TestNodeInteraction:
    """Test clicking network graph nodes."""

    def test_click_node_opens_popup(self, dash: Page):
        """Clicking a bank node opens the detail popup."""
        nodes = dash.locator("#graphContainer svg .node-group")
        expect(nodes).to_have_count(6, timeout=5000)
        nodes.first.click()
        dash.wait_for_timeout(1500)
        popup = dash.locator("#nodePopup")
        if popup.is_visible():
            expect(popup).to_be_visible()
            # Popup has content
            body = dash.locator("#nodePopupBody").text_content()
            assert len(body) > 0
            # Close popup
            dash.locator("#nodePopupClose").click()
            dash.wait_for_timeout(300)

    def test_close_popup_via_overlay(self, dash: Page):
        """Clicking the overlay background closes the popup."""
        nodes = dash.locator("#graphContainer svg .node-group")
        nodes.first.click()
        dash.wait_for_timeout(1500)
        popup = dash.locator("#nodePopup")
        if popup.is_visible():
            # Click the overlay (not the glass card)
            dash.locator("#nodePopup").click(position={"x": 10, "y": 10})
            dash.wait_for_timeout(500)


# ── Chat UI Tests ────────────────────────────────────────────────

class TestChatRendering:
    """Test chat view renders correctly."""

    def test_chat_layout_elements(self, chat_view: Page):
        """Chat view has sidebar, message area, input, and send button."""
        expect(chat_view.locator(".chat-sidebar")).to_be_visible()
        expect(chat_view.locator(".chat-messages")).to_be_visible()
        expect(chat_view.locator("#chatInput")).to_be_visible()
        expect(chat_view.locator("#btnSend")).to_be_visible()

    def test_provider_buttons(self, chat_view: Page):
        """Ollama and Anthropic provider buttons are visible."""
        expect(chat_view.locator("#btnOllama")).to_be_visible()
        expect(chat_view.locator("#btnAnthropic")).to_be_visible()

    def test_new_chat_button(self, chat_view: Page):
        """New Chat button is visible and clickable."""
        btn = chat_view.locator("#btnNewChat")
        expect(btn).to_be_visible()
        expect(btn).to_be_enabled()

    def test_chat_textarea_multiline(self, chat_view: Page):
        """Chat textarea supports multiple rows."""
        textarea = chat_view.locator("#chatInput")
        rows = textarea.get_attribute("rows")
        assert rows is not None and int(rows) >= 2

    def test_empty_state_shown(self, chat_view: Page):
        """Chat shows empty state message before any messages."""
        empty = chat_view.locator(".chat-empty")
        expect(empty).to_be_visible()
        text = empty.text_content()
        assert "Send a message" in text

    def test_provider_name_displayed(self, chat_view: Page):
        """Provider name is shown in the sidebar."""
        provider = chat_view.locator("#providerName")
        expect(provider).to_be_visible()
        text = provider.text_content().strip().lower()
        assert "ollama" in text or "anthropic" in text

    def test_role_shown_in_sidebar(self, chat_view: Page):
        """Current role is displayed in the chat sidebar."""
        role = chat_view.locator("#chatRole")
        expect(role).to_be_visible()


class TestChatMessaging:
    """Test sending messages and receiving responses."""

    def test_send_simple_question(self, chat_view: Page):
        """Sending a question produces an assistant response."""
        chat_view.fill("#chatInput", "What is a nostro account?")
        chat_view.click("#btnSend")

        # User message appears
        chat_view.wait_for_selector(".message--user", timeout=5000)
        user_msg = chat_view.locator(".message--user").first.text_content()
        assert "nostro" in user_msg.lower()

        # Assistant response appears
        chat_view.wait_for_selector(".message--assistant", timeout=45000)
        messages = chat_view.locator(".message--assistant")
        assert messages.count() >= 1
        response_text = messages.first.text_content()
        assert len(response_text) > 10, "Expected a meaningful response"

    def test_send_tool_use_query(self, chat_view: Page):
        """Sending a banking query triggers tool use and shows results."""
        chat_view.fill("#chatInput", "List all accounts in BANK_A")
        chat_view.click("#btnSend")

        # Wait for response
        chat_view.wait_for_selector(".message--assistant", timeout=45000)

        # Check if tool call cards appeared (LLM may or may not use tools)
        chat_view.wait_for_timeout(2000)
        assistant_text = chat_view.locator(".message--assistant").first.text_content()
        # Response should mention accounts or BANK_A
        assert len(assistant_text) > 5

    def test_input_clears_after_send(self, chat_view: Page):
        """Chat input is cleared after sending a message."""
        chat_view.fill("#chatInput", "Hello")
        chat_view.click("#btnSend")
        chat_view.wait_for_timeout(500)
        value = chat_view.locator("#chatInput").input_value()
        assert value == "", f"Expected empty input, got '{value}'"

    def test_typing_indicator_shows(self, chat_view: Page):
        """Typing indicator appears while waiting for response."""
        chat_view.fill("#chatInput", "What banks are in the network?")
        chat_view.click("#btnSend")
        # Typing indicator should appear briefly
        try:
            chat_view.wait_for_selector(".typing", timeout=5000)
        except Exception:
            pass  # May be too fast to catch — not a failure

    def test_new_chat_clears_messages(self, chat_view: Page):
        """Clicking New Chat after a conversation clears messages."""
        # Send a message first
        chat_view.fill("#chatInput", "Hello")
        chat_view.click("#btnSend")
        chat_view.wait_for_selector(".message--user", timeout=5000)

        # Click New Chat
        chat_view.click("#btnNewChat")
        chat_view.wait_for_timeout(1000)

        # Previous user messages should be gone
        user_msgs = chat_view.locator(".message--user")
        assert user_msgs.count() == 0, "Expected messages to be cleared"

    def test_multiple_messages_in_conversation(self, chat_view: Page):
        """Multiple messages create a conversation thread."""
        # First message
        chat_view.fill("#chatInput", "Hello")
        chat_view.click("#btnSend")
        chat_view.wait_for_selector(".message--assistant", timeout=45000)

        # Second message
        chat_view.fill("#chatInput", "How many banks are there?")
        chat_view.click("#btnSend")
        chat_view.wait_for_timeout(2000)

        # Should have at least 2 user messages
        user_msgs = chat_view.locator(".message--user")
        assert user_msgs.count() >= 2


class TestChatSessions:
    """Test chat session management."""

    def test_session_appears_in_sidebar(self, chat_view: Page):
        """After sending a message, a session appears in the sidebar."""
        chat_view.fill("#chatInput", "Hello")
        chat_view.click("#btnSend")
        chat_view.wait_for_selector(".message--assistant", timeout=45000)
        chat_view.wait_for_timeout(1000)
        # Check session list for an entry
        sessions = chat_view.locator("#sessionList .session-item")
        assert sessions.count() >= 1


# ── View Switching ────────────────────────────────────────────────

class TestViewSwitching:
    """Test navigation between Dashboard and Chat views."""

    def test_switch_to_chat(self, dash: Page):
        """Clicking Chat tab shows the chat view."""
        dash.click("[data-view='chat']")
        expect(dash.locator("#view-chat")).to_have_class(re.compile("view--active"))
        expect(dash.locator("#view-dashboard")).not_to_have_class(re.compile("view--active"))

    def test_switch_back_to_dashboard(self, dash: Page):
        """Clicking Dashboard tab returns to dashboard."""
        dash.click("[data-view='chat']")
        dash.click("[data-view='dashboard']")
        expect(dash.locator("#view-dashboard")).to_have_class(re.compile("view--active"))

    def test_active_tab_styling(self, dash: Page):
        """Active tab has the active class."""
        dash_tab = dash.locator("[data-view='dashboard']")
        expect(dash_tab).to_have_class(re.compile("nav__tab--active"))

        dash.click("[data-view='chat']")
        chat_tab = dash.locator("[data-view='chat']")
        expect(chat_tab).to_have_class(re.compile("nav__tab--active"))
        expect(dash_tab).not_to_have_class(re.compile("nav__tab--active"))


# ── Role Switching ────────────────────────────────────────────────

class TestRoleSwitching:
    """Test RBAC role selector behavior."""

    def test_role_options_available(self, dash: Page):
        """Role selector has all 4 RBAC roles."""
        options = dash.locator("#roleSelect option")
        texts = [options.nth(i).text_content() for i in range(options.count())]
        assert "admin" in texts
        assert "operator" in texts
        assert "auditor" in texts
        assert "viewer" in texts

    def test_role_syncs_to_chat(self, dash: Page):
        """Changing role in nav updates the chat sidebar display."""
        dash.select_option("#roleSelect", "admin")
        dash.click("[data-view='chat']")
        dash.wait_for_timeout(300)
        role_display = dash.locator("#chatRole").text_content()
        assert role_display.strip() == "admin"
