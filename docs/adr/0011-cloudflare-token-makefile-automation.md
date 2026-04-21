# 0011 - Cloudflare Token Makefile Automation

Date: 2025-11-05
Status: Accepted
Author: vld.lazar@proton.me
Implemented: 2025-11-05
Files-changed: Makefile (3 rules), settings/*/cloudflare_token.age
Related-ADRs: #0009
Tags: automation, cloudflare, secrets, makefile, age

## Summary

Created 3 Makefile rules to automate Cloudflare token management: `create_cloudflare_token`
(secure interactive input), `show_cloudflare_token` (decrypt and display), `check_cloudflare_token`
(validate). Tokens stored in plain format at `settings/SERVER_ID/cloudflare_token.age`. During
`generate_all_scripts`, a certbot-formatted version (`cloudflare_token_nginx.age`) is automatically
generated for Let's Encrypt DNS-01 automation. Fixed `check_age_recipients` bug.

## Quick Reference

| Item | Value |
|------|-------|
| **Commands** | `make create_cloudflare_token`, `show_cloudflare_token`, `check_cloudflare_token` |
| **Files** | `Makefile:431-471`, `settings/SERVER_ID/cloudflare_token.age` |
| **Bug fix** | `Makefile:424` added `-s` flag to detect empty recipient files |
| **Workflows** | See `docs/adr/references/cloudflare-token-workflows.md` |

## Context

ADR #0009 established Age-encrypted storage for Cloudflare API tokens, but operators had to:
- Manually create plaintext token files
- Manually encrypt with Age using complex commands
- Remember Age syntax with correct recipient files
- No validation that encryption/decryption works

Additionally, `check_age_recipients` had a bug: it only checked file existence, not content.
Empty recipient files would pass checks but encryption would fail.

**Requirements:** Interactive token creation, automatic encryption, validation, safe temp file
handling, view decrypted tokens, fix empty file detection, POSIX sh-compatible.

## Decision

Implement three Makefile rules for complete Cloudflare token lifecycle management.

### 1. create_cloudflare_token

Interactive rule that securely creates Age-encrypted token files.

**Features:**
- Prompts for token with hidden input (`stty -echo`)
- Stores token in plain format (just the token value, no prefix)
- Auto-encrypts with server's Age recipient key
- Secure temp file (0600 permissions, auto-cleanup via trap)
- Overwrite protection
- Automatic decryption test after creation

**Usage:** `make settings=SERVER_ID create_cloudflare_token`

**Implementation:** Uses `.ONESHELL:`, POSIX `stty`, dependencies on `check_age_ident` and
`check_age_recipients`, creates `$(SERVER_SETTINGS_PATH)/cloudflare_token.age`. Plain format
enables both local use (wellknown scripts) and certbot format generation.

### 2. show_cloudflare_token

Non-interactive rule that decrypts and displays token to stdout.

**Features:**
- Decrypts using local Age identity
- Outputs plain token value to stdout (pipeable)
- Errors to stderr

**Usage:**
```bash
make settings=SERVER_ID show_cloudflare_token
make settings=SERVER_ID show_cloudflare_token | wc -c  # Check token length
```

### 3. check_cloudflare_token

Validation rule with improved error messages. Points to `create_cloudflare_token` for fixes.
Only runs when `ENABLE_NGINX := 1`.

### 4. Certbot Format Generation (generate_all_scripts)

During `make generate_all_scripts`, if NGINX is enabled, the plain token is automatically
converted to certbot format for Let's Encrypt DNS-01 automation.

**Process:**
1. Decrypt plain token from `settings/SERVER_ID/cloudflare_token.age`
2. Generate certbot format: `dns_cloudflare_api_token = TOKEN`
3. Encrypt as `out/SERVER_ID/secrets/cloudflare_token_nginx.age`
4. Deploy script copies nginx version to `/root/.secrets/certbot/cloudflare_token.age`

**Benefits:** Single source token, automatic format conversion, local scripts use plain format,
remote certbot uses formatted version, no manual file management.

### 5. check_age_recipients (Bug Fix)

**Before (buggy):**
```makefile
if [ ! -f "$(SERVER_AGE_RECIPIENTS_FN)" ]; then
```

**After (fixed):**
```makefile
if [ ! -f "$(SERVER_AGE_RECIPIENTS_FN)" ] || [ ! -s "$(SERVER_AGE_RECIPIENTS_FN)" ]; then
```

**Key change:** Added `|| [ ! -s ... ]` to detect empty (0-byte) files. The `-s` flag returns
false if file is empty. Now automatically regenerates empty recipient files.

## Token Format Evolution

**Original (ADR #0009):** Token stored with certbot prefix: `dns_cloudflare_api_token = TOKEN`
**Current:** Token stored in plain format, certbot version generated during `generate_all_scripts`
**Rationale:** Plain format enables dual use - local scripts (wellknown configuration via Cloudflare
API) and remote scripts (certbot Let's Encrypt). Single source, multiple formats.

## Consequences

**Positive:** Secure by default (hidden input, auto-cleanup), fool-proof (interactive prompts),
self-validating (auto decryption test), consistent workflow, discoverable (`make help`), portable
(POSIX sh), debuggable (`show_cloudflare_token`), prevents silent failures (empty file detection),
ADR #0009 compliant.

**Negative:** Requires TTY (won't work in non-interactive scripts), no automatic token rotation,
requires local Age identity, requires `stty` command.

**Risks:** Clipboard logging during paste (mitigation: user awareness), TTY requirement for
automation (mitigation: can manually encrypt or use expect), token briefly in memory (mitigation:
temp file immediately deleted, process memory cleared on exit).

### Follow-up Work

- [ ] Add `rotate_cloudflare_token` (archives old token before creating new)
- [ ] Add token expiration check (query Cloudflare API)
- [ ] Add token validation against Cloudflare API (verify permissions)

## Alternatives

### A: Separate shell script for token management
`scripts/create_cloudflare_token.sh SERVER_ID`
- **Pro:** More feature-rich, easier to test
- **Con:** Another file to maintain, breaks Makefile-centric workflow
- **Rejected:** Inconsistent with Makefile-based approach

### B: Store plaintext tokens in extended_settings.mk
- **Pro:** Simple, no encryption
- **Con:** Security risk, tokens in version control
- **Rejected:** Violates ADR #0009

### C: Use bash read -s for hidden input
- **Pro:** Single command, cleaner syntax
- **Con:** Requires bash, not POSIX
- **Rejected:** Project prefers sh compatibility (ADR #0012)

## References

- **Workflows and security:** `docs/adr/references/cloudflare-token-workflows.md`
- ADR #0009: Cloudflare Token Storage via Age Encryption
- ADR #0008: Let's Encrypt Automation Behind Cloudflare
- Age encryption: https://age-encryption.org/
- POSIX stty: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/stty.html
