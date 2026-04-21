# 0009 — Cloudflare Token Storage via Age Encryption
Date: 2025-11-01
Status: Accepted (implemented by #0011)
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: repository operators, security reviewers
Informed: automation contributors
Tags: tls, secrets, age, nginx

## Context
ADR 0008 introduced automated Let's Encrypt provisioning but required the Cloudflare API token to live directly in
`extended_settings.mk`. Even with repository access controls, committing plaintext credentials is risky and conflicts
with the project's guidance to keep secrets encrypted with Age. We need a way to keep token deployment automated while
allowing the token blob to reside safely alongside other server settings in source control.

## Decision
Store the Cloudflare API token as an Age-encrypted artifact under `settings/<server_id>/cloudflare_token.age` in plain
format (just the token value), using the per-server recipient list (`server_age_recipients.txt`). During
`generate_all_scripts`, a certbot-formatted version (`dns_cloudflare_api_token = TOKEN`) is automatically generated
as `cloudflare_token_nginx.age` for Let's Encrypt DNS-01 automation. The nginx Let's Encrypt script decrypts the
certbot-formatted blob at runtime via `age -d -i <identity> <encrypted-file>` directly to a temporary credentials file.
The temporary file is automatically deleted via trap handler on script exit. Settings variables:
- `letsencrypt_cloudflare_token_age_path` - Path to Age-encrypted certbot-formatted token on server
- `letsencrypt_age_identity_path` - Age identity file for decryption

**Security improvement**: The decrypted API token never persists on disk. The token lifecycle is:
1. Stored in plain format at `settings/SERVER_ID/cloudflare_token.age` (Age-encrypted, used locally)
2. During `generate_all_scripts`, converted to certbot format and encrypted as `cloudflare_token_nginx.age`
3. Deployed to server at `/root/.secrets/certbot/cloudflare_token.age` (Age-encrypted certbot format)
4. Let's Encrypt script decrypts directly to temporary file via `mktemp` with 0600 permissions
5. Used by certbot's Cloudflare DNS plugin
6. Automatically deleted when the script exits (via trap on EXIT, INT, TERM signals)

The temporary file exists only during script execution and is immediately removed on completion or failure. This is
more secure than storing plaintext credentials permanently. Plain format storage enables dual use: local scripts
(Cloudflare API for wellknown configuration) and remote scripts (certbot).

Operators must copy the encrypted blob and matching Age identity to the server before execution; documentation in
`docs/letsencrypt-cloudflare.md` now covers the process. This decision amends ADR 0008 by changing how the script
obtains Cloudflare credentials.

## Consequences
- Positive:
  - Secrets stay encrypted at rest in the repository yet remain available to automation with minimal manual steps
  - Decrypted token exists only temporarily during script execution
  - Temporary file created with secure permissions (0600, umask 077)
  - Automatic cleanup via trap handler even on script failures
  - No persistent plaintext credentials on server filesystem
  - Works with certbot's standard --dns-cloudflare-credentials mechanism
- Negative:
  - Requires securely distributing the Age identity to the target host; compromise of that key exposes the token
  - Temporary file briefly exists in /tmp during script execution (but only readable by root)
- Risks/Trade-offs:
  - The script depends on the `age` package being available on the server
  - Will fail if operators forget to place encrypted token on server
  - Temporary file could theoretically be read from /tmp if an attacker has root access during execution window
- Follow-up work: Consider adding CI checks ensuring placeholder Age files are not shipped to production, and explore
  per-host Age identities to scope blast radius.

## Alternatives
- Keep plaintext token in environment variables — rejected: still risks accidental logging and lacks at-rest
  encryption.
- Prompt operators interactively for the token — rejected: breaks unattended runs and encourages insecure reuse.

## References
- ADR 0008 — Let's Encrypt automation behind Cloudflare
- `templates/nginx/e060-nginx/a05-request_letsencrypt.sh`
- `docs/letsencrypt-cloudflare.md`
