@echo off
:: VibeRaise - claude.cmd wrapper
:: This file sits in front of the real claude binary.
:: It calls the Python wrapper which watches output and raises the window.
python "%~dp0claude-wrapper.py" %*
