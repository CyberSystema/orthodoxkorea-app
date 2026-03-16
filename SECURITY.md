# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please email: **security@orthodoxkorea.org**

Include:
- A description of the vulnerability
- Steps to reproduce it
- The potential impact
- Suggested fix (if any)

We will acknowledge your report within 48 hours and provide a timeline for a fix.

## Security Measures

This app implements the following security measures:

- **Domain allowlist**: Only approved domains can be loaded in the WebView
- **HTTPS enforcement**: All non-HTTPS requests are blocked
- **No hardcoded secrets**: API keys are stored in platform-specific config files, not in source code
- **ProGuard**: Android release builds use code minification and resource shrinking
- **Code signing**: iOS builds use Apple's code signing; Android uses a separate keystore (excluded from version control)

## Scope

The following are considered in-scope for security reports:

- Vulnerabilities in the app's Swift/Kotlin source code
- WebView security bypasses (domain restriction, HTTPS enforcement)
- Exposed secrets or credentials
- Insecure data storage

The following are out-of-scope:

- Vulnerabilities in the orthodoxkorea.org website itself
- Issues in third-party dependencies (report these to the respective maintainers)
- Social engineering attacks
