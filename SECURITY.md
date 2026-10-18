# Security

## Reporting a vulnerability

Please report vulnerabilities privately via
[GitHub Security Advisories](https://github.com/telip007/stipple/security/advisories/new)
rather than public issues. We aim to respond within a week.

## API keys

- Never include API keys in issues, PRs, logs or test fixtures. If you
  accidentally publish one, revoke it immediately at https://openrouter.ai/keys.
- Don't embed API keys in distributed apps. Use per-user keys via OAuth PKCE
  or proxy requests through your own backend.
