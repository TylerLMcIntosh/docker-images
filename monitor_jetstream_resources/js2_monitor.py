#!/usr/bin/env python3
"""
Jetstream2 r3.xl large memory node availability monitor.

Runs via Windows Task Scheduler (every 5 min).
Notifies (toast + ntfy.sh push) when availability rises above 1.

State is persisted in js2_state.json (same folder as this script).
Config lives in js2_config.json — see CONFIG section below.

Notification options (set in js2_config.json):
  ntfy_topic      — free push via https://ntfy.sh  (recommended, no account needed)
  gmail_app_password — Gmail SMTP fallback (requires Google app password)
Either, both, or neither (toast-only) will work.

Usage:
  python js2_monitor.py            # normal scheduled run
  python js2_monitor.py --debug    # save raw page text for inspection
  python js2_monitor.py --test     # fire test notifications immediately (no page fetch)
"""

import asyncio
import json
import re
import smtplib
import subprocess
import sys
import urllib.request
from email.mime.text import MIMEText
from pathlib import Path

# ── constants ──────────────────────────────────────────────────────────────────

GRAFANA_URL = (
    "https://grafana.jetstream-cloud.org/public-dashboards/"
    "b39f9f91452949389a4d333c3f451eac"
)
EMAIL_ADDR  = "tylermcintosh7@gmail.com"
SCRIPT_DIR  = Path(__file__).parent
STATE_FILE  = SCRIPT_DIR / "js2_state.json"
CONFIG_FILE = SCRIPT_DIR / "js2_config.json"
LOG_FILE    = SCRIPT_DIR / "js2_monitor.log"

# ── helpers ────────────────────────────────────────────────────────────────────

def log(msg: str):
    import datetime
    line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    with LOG_FILE.open("a") as f:
        f.write(line + "\n")


def load_json(path: Path, default: dict) -> dict:
    try:
        return json.loads(path.read_text()) if path.exists() else default
    except Exception:
        return default


def save_json(path: Path, data: dict):
    path.write_text(json.dumps(data, indent=2))


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        log(f"ERROR: Config file not found at {CONFIG_FILE}")
        log("Run setup_monitor.ps1 first to create js2_config.json.")
        sys.exit(1)
    return load_json(CONFIG_FILE, {})


# ── page scraping ──────────────────────────────────────────────────────────────

async def fetch_r3xl_count(debug: bool = False) -> int | None:
    """
    Launches headless Chromium, loads the Grafana dashboard, and parses
    the current available count for r3.xl large memory nodes.
    Returns the integer count, or None if parsing fails.
    """
    from playwright.async_api import async_playwright

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        try:
            page = await browser.new_page()
            log("Loading Grafana dashboard...")
            await page.goto(GRAFANA_URL, wait_until="networkidle", timeout=60_000)

            # Give JS panels extra time to populate data
            await page.wait_for_timeout(6_000)

            # Pull rendered text from the page body
            text: str = await page.evaluate("() => document.body.innerText")

            if debug:
                (SCRIPT_DIR / "js2_debug_page_text.txt").write_text(text)
                log("Debug: page text saved to js2_debug_page_text.txt")

            return _parse_r3xl(text)
        finally:
            await browser.close()


def _parse_r3xl(text: str) -> int | None:
    """
    Tries several patterns to find the availability count for r3.xl.
    The Grafana page renders something like:
        r3.xl large memory
        0              ← current availability
        ...history...

    Returns the first integer found near the r3.xl label.
    """
    # Normalise whitespace so multi-line patterns work on \n-joined text
    flat = " ".join(text.split())

    # Pattern 1: "r3.xl" followed (within 60 chars) by a standalone number
    m = re.search(r"r3[\.\s\-]?xl[^0-9]{0,60}?(\d+)", flat, re.IGNORECASE)
    if m:
        return int(m.group(1))

    # Pattern 2: "large memory" followed by a number (fallback)
    m = re.search(r"large\s+memory[^0-9]{0,40}?(\d+)", flat, re.IGNORECASE)
    if m:
        return int(m.group(1))

    return None


# ── notifications ──────────────────────────────────────────────────────────────

def send_toast(title: str, body: str):
    """Windows 10/11 toast via PowerShell WinRT bindings."""
    # Escape single-quotes for PowerShell string safety
    title = title.replace("'", "\\'")
    body  = body.replace("'", "\\'")

    ps = f"""
[Windows.UI.Notifications.ToastNotificationManager,
 Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument,
 Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml('<toast><visual><binding template="ToastGeneric"><text>{title}</text><text>{body}</text></binding></visual></toast>')
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Jetstream2 Monitor').Show($toast)
"""
    result = subprocess.run(
        ["powershell", "-WindowStyle", "Hidden", "-NonInteractive", "-Command", ps],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"Toast warning: {result.stderr.strip()}")


def send_ntfy(topic: str, title: str, body: str):
    """Push notification via ntfy.sh — no account or password needed."""
    data = body.encode()
    req  = urllib.request.Request(
        f"https://ntfy.sh/{topic}",
        data=data,
        headers={"Title": title, "Priority": "high", "Tags": "bell"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()


def send_email(subject: str, body: str, app_password: str):
    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"]    = EMAIL_ADDR
    msg["To"]      = EMAIL_ADDR

    with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=15) as server:
        server.login(EMAIL_ADDR, app_password)
        server.send_message(msg)


def notify(count: int, last: int | None, config: dict):
    subject    = f"Jetstream2 r3.xl available: {count} node(s)"
    prev       = f"previously: {last}" if last is not None else "first detection"
    long_body  = (
        f"{count} r3.xl large memory node(s) are now available on Jetstream2.\n"
        f"({prev})\n\n"
        f"Dashboard:\n{GRAFANA_URL}\n"
    )
    short_body = f"{count} node(s) available ({prev})"

    log(f"ALERT — sending notifications: {subject}")
    send_toast(subject, short_body)

    ntfy_topic = config.get("ntfy_topic", "")
    if ntfy_topic:
        try:
            send_ntfy(ntfy_topic, subject, long_body)
            log(f"ntfy.sh notification sent to topic '{ntfy_topic}'.")
        except Exception as e:
            log(f"ntfy.sh failed: {e}")
    else:
        log("No ntfy_topic configured — skipping push notification.")

    app_password = config.get("gmail_app_password", "")
    if app_password:
        try:
            send_email(subject, long_body, app_password)
            log("Email sent.")
        except Exception as e:
            log(f"Email failed: {e}")
    else:
        log("No gmail_app_password configured — skipping email.")


# ── main ───────────────────────────────────────────────────────────────────────

async def main():
    debug     = "--debug" in sys.argv
    test_mode = "--test" in sys.argv

    config = load_config()
    state  = load_json(STATE_FILE, {"last_count": None, "alert_sent_at_count": None})

    # --test fires notifications immediately with fake data, skips page fetch
    if test_mode:
        log("TEST MODE — firing a test notification (not reading the live page).")
        notify(count=3, last=1, config=config)
        log("Test done. Check for a toast pop-up and ntfy.sh/email if configured.")
        return

    count = await fetch_r3xl_count(debug=debug)

    if count is None:
        log("Could not parse r3.xl count from page. Run with --debug to inspect page text.")
        sys.exit(0)

    log(f"r3.xl available: {count}  |  last known: {state.get('last_count')}")

    last          = state.get("last_count")
    alert_sent_at = state.get("alert_sent_at_count")

    # Notify when count rises above 1 and is higher than the last alert level.
    # (Threshold is >1 because the user wants more than a single node available.)
    # Don't repeat the alert while the count stays the same.
    should_notify = (
        count > 1
        and count > (alert_sent_at or 1)
    )

    if should_notify:
        notify(count, last, config)
        state["alert_sent_at_count"] = count
    elif count <= 1 and alert_sent_at:
        # Reset so the alert fires again next time count climbs above 1
        state["alert_sent_at_count"] = None
        log("Count back to 1 or below — alert will re-fire on next rise above 1.")

    state["last_count"] = count
    save_json(STATE_FILE, state)


if __name__ == "__main__":
    asyncio.run(main())
