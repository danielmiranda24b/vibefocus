#!/usr/bin/env python3
"""
VibeRaise - Windows Claude Code wrapper
Watches Claude's output and brings the terminal window to the front
whenever Claude is waiting for your input.
"""

import os
import re
import sys
import time
import signal
import subprocess
import threading
import queue
import shutil

# ── Config ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
FOCUS_SCRIPT = os.path.join(SCRIPT_DIR, "focus-window.ps1")

# Patterns in Claude's output that mean it's waiting for user input
PROMPT_PATTERNS = [
    rb'\?\s*$',                    # line ending with ?
    rb'^\s*>\s*$',                 # bare > prompt
    rb'\(y/n\)',                   # yes/no prompt
    rb'\[y/N\]',
    rb'[Pp]ress [Ee]nter',
    rb'[Cc]ontinue\?',
    rb'Allow .+\?',                # Claude Code permission prompt
    rb'Do you want to',
    rb'Would you like',
    rb'Shall I',
    rb'\[Y/n\]',
    rb'\[yes/no\]',
]

def focus_window():
    """Bring the terminal window to the foreground using PowerShell."""
    if os.path.isfile(FOCUS_SCRIPT):
        subprocess.Popen(
            ["powershell", "-ExecutionPolicy", "Bypass",
             "-WindowStyle", "Hidden", "-File", FOCUS_SCRIPT],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
        )

def looks_like_prompt(buf: bytes) -> bool:
    """Return True if the tail of the output buffer matches a waiting-for-input pattern."""
    last_line = buf.strip().split(b"\n")[-1] if buf.strip() else b""
    return any(re.search(p, last_line) for p in PROMPT_PATTERNS)

def find_claude_real():
    """Find the real claude binary (claude-real.cmd, claude-real, etc.)."""
    candidates = [
        os.path.join(SCRIPT_DIR, "claude-real.cmd"),
        os.path.join(SCRIPT_DIR, "claude-real.bat"),
        os.path.join(SCRIPT_DIR, "claude-real"),
    ]
    # Also search PATH for claude-real
    found = shutil.which("claude-real")
    if found:
        candidates.insert(0, found)
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

def main():
    real_claude = find_claude_real()
    if not real_claude:
        sys.stderr.write(
            "vibeRaise wrapper: claude-real not found.\n"
            "Run install.ps1 to set up the wrapper.\n"
        )
        sys.exit(1)

    # On Windows we use subprocess with pipes — no PTY needed
    cmd = [real_claude] + sys.argv[1:]

    # If it's a .cmd/.bat, invoke through cmd.exe
    if real_claude.endswith((".cmd", ".bat")):
        cmd = ["cmd", "/c", real_claude] + sys.argv[1:]

    proc = subprocess.Popen(
        cmd,
        stdin=sys.stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
    )

    output_buf = b""
    focused_for_current_prompt = False

    def reader():
        nonlocal output_buf, focused_for_current_prompt
        while True:
            chunk = proc.stdout.read(256)
            if not chunk:
                break

            # Write to our stdout so user sees it
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()

            output_buf = (output_buf + chunk)[-4096:]

            if looks_like_prompt(output_buf):
                if not focused_for_current_prompt:
                    focused_for_current_prompt = True
                    focus_window()
            else:
                # Claude is actively outputting — reset so next prompt triggers again
                focused_for_current_prompt = False

    t = threading.Thread(target=reader, daemon=True)
    t.start()

    try:
        proc.wait()
    except KeyboardInterrupt:
        proc.terminate()
        proc.wait()
    finally:
        t.join(timeout=2)
        # Always focus terminal when Claude exits
        focus_window()

if __name__ == "__main__":
    main()
