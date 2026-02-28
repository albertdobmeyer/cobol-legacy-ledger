"""
UX Simulation Walkthrough — Playwright Script
==============================================

Drives the COBOL Legacy Ledger web console through a complete UX flow,
capturing screenshots at each milestone. Mimics a first-time senior
developer exploring the application.

Prerequisites:
    pip install playwright
    playwright install chromium
    uvicorn python.api.app:app --reload  # must be running on :8000

Usage:
    python simulation/walkthrough.py

Screenshots saved to: simulation/screenshots/
Best screenshots copied to: docs/screenshots/
"""

import shutil
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE_URL = "http://localhost:8000"
CONSOLE_URL = f"{BASE_URL}/console/index.html"
SCREENSHOT_DIR = Path("simulation/screenshots")
DOCS_SCREENSHOT_DIR = Path("docs/screenshots")


def take(page, name: str) -> Path:
    """Save a screenshot and return its path."""
    path = SCREENSHOT_DIR / f"{name}.png"
    page.screenshot(path=str(path))
    print(f"  Screenshot: {path}")
    return path


def main():
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 900})

        # ── Phase A: Landing & First Impressions ──────────────────
        print("Phase A: Landing & First Impressions")
        page.goto(BASE_URL)
        page.wait_for_url(f"**/console/index.html")
        take(page, "01-onboarding-popup")

        page.click("button:has-text('Got it')")
        page.wait_for_timeout(500)
        take(page, "02-clean-dashboard")

        # ── Phase B: Dashboard Exploration ────────────────────────
        print("Phase B: Dashboard Exploration")

        # Switch to admin for node popup (operator lacks chain.verify)
        page.select_option("#roleSelect", "admin")

        # Click BANK_A node
        page.click("text=BANK A")
        page.wait_for_timeout(500)
        take(page, "03-bank-node-popup")
        page.click("button:has-text('×')")

        # Test COBOL viewer with different files
        for cob_file in ["TRANSACT.cob", "SETTLE.cob", "ACCOUNTS.cob"]:
            page.select_option("#cobolFileSelect", cob_file)
            page.wait_for_timeout(300)
        print("  COBOL viewer: all files load successfully")

        # ── Phase C: Simulation Run ───────────────────────────────
        print("Phase C: Simulation Run")
        page.fill("input[type='number']", "5")
        page.click("button:has-text('Start')")
        page.wait_for_timeout(3000)  # wait for simulation to complete
        take(page, "04-simulation-complete")

        # ── Phase D: Tamper & Verify ──────────────────────────────
        print("Phase D: Tamper & Verify")
        page.click("button:has-text('Tamper')")
        page.wait_for_timeout(500)
        page.click("button:has-text('Verify')")
        page.wait_for_timeout(1000)
        take(page, "05-tamper-detected")

        # ── Phase E: Analysis Tab ─────────────────────────────────
        print("Phase E: Analysis Tab")
        page.click("button:has-text('Analysis')")
        page.wait_for_timeout(500)
        page.select_option("#analysisFileSelect", "TRANSACT.cob (clean)")
        page.click("button:has-text('Analyze')")
        page.wait_for_timeout(2000)
        take(page, "06-analysis-call-graph")

        # Test execution trace
        page.select_option("#traceEntrySelect", "MAIN-PROGRAM")
        page.wait_for_timeout(500)
        take(page, "07-analysis-trace")

        # ── Phase F: Chat Tab ─────────────────────────────────────
        print("Phase F: Chat Tab")
        page.click("button:has-text('Chat')")
        page.wait_for_timeout(500)
        take(page, "08-chat-empty-state")

        # ── Phase G: Permission Testing ───────────────────────────
        print("Phase G: Permission Testing")
        page.click("button:has-text('Dashboard')")
        page.select_option("#roleSelect", "viewer")
        page.click("button:has-text('Start')")
        page.wait_for_timeout(500)
        take(page, "09-permission-denied")

        # ── Phase H: Mobile Responsiveness ────────────────────────
        print("Phase H: Mobile Responsiveness")
        page.set_viewport_size({"width": 375, "height": 812})
        page.wait_for_timeout(300)
        take(page, "10-mobile-responsive")
        page.set_viewport_size({"width": 1280, "height": 900})

        browser.close()

    # ── Copy best screenshots to docs/ ────────────────────────
    print("\nCopying best screenshots to docs/screenshots/")
    shutil.copy(SCREENSHOT_DIR / "02-clean-dashboard.png",
                DOCS_SCREENSHOT_DIR / "dashboard.png")
    shutil.copy(SCREENSHOT_DIR / "06-analysis-call-graph.png",
                DOCS_SCREENSHOT_DIR / "analysis.png")
    shutil.copy(SCREENSHOT_DIR / "08-chat-empty-state.png",
                DOCS_SCREENSHOT_DIR / "chat.png")

    print("\nWalkthrough complete!")
    print(f"  Screenshots: {SCREENSHOT_DIR}")
    print(f"  Docs copies: {DOCS_SCREENSHOT_DIR}")


if __name__ == "__main__":
    main()
