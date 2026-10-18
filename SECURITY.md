# Security

## Reporting a vulnerability

Please report vulnerabilities privately via
[GitHub Security Advisories](https://github.com/telip007/stipple/security/advisories/new)
rather than public issues. We aim to respond within a week.

## Scope

Stipple reads from and writes to a terminal, so the relevant issues include
escape-sequence injection (untrusted text that can move the cursor, change the
title or otherwise escape its cell), crashes on malformed input bytes, and
paths that leave the terminal in raw mode or on the alternate screen.

Please include a minimal reproduction and the terminal emulator you used.
