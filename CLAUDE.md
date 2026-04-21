# MDIST-LIGHT Project - Claude Instructions

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me

## Project Goal

Create automation scripts to configure servers. Self-made Makefile-based solution,
simplified version of cdist.

**Current servers:**
- my_chatmail_server - Delta Chat chatmail server with webhook bot

## Quick Navigation

- **Getting started?** Read `docs/adr/0000-index.md` first
- **Session continuity?** Check `docs/claude/PROJECT_NOTES.md` for current work status
- **User requests history?** Check `docs/user-requests/YYYY-MM-DD.md` for daily request logs
- **Writing ADRs?** See `docs/claude/adr-guidelines.md`
- **Shell scripting?** See ADR #0012 + `docs/adr/references/posix-sh-reference.md`
- **Adding features?** See ADR #0004 + `docs/adr/references/feature-generation-examples.md`
- **Deploying?** See ADR #0010 + `docs/adr/references/deployment-workflows.md`

## Project Structure

```
./Makefile                  - Main automation (build, deploy, validation)
./docs/adr/                 - Architecture Decision Records
./docs/claude/              - Claude-specific guidelines
./docs/user-requests/       - Daily log of user requests (YYYY-MM-DD.md format)
./out/SERVER_ID/            - Generated deployment scripts (ready to deploy)
./scripts/                  - Common utilities and validation scripts
./settings/SERVER_ID/       - Server-specific configuration
  |- server_settings.mk    - Server config, feature flags
  |- extended_settings.mk  - Deployment settings, secrets paths
  `- *.age                 - Encrypted secrets (safe to commit)
./templates/FEATURE/        - Code templates organized by feature
./tests/                    - Project tests
./tmp/                      - Temporary files
```

## Common Make Commands

```bash
# Get help on make commands
make settings=SERVER_ID help                  # Show available commands and help messages for them
make settings=SERVER_ID help_all              # Show all commands that are in makefile and help messages

# Generation
make settings=SERVER_ID generate_all_scripts  # Generate deployment scripts

# Deployment
make settings=SERVER_ID deploy                # Full deployment (copy + run)
make settings=SERVER_ID deploy_check          # Dry-run deployment
make settings=SERVER_ID deploy_copy           # Copy scripts only
make settings=SERVER_ID deploy_run            # Execute on remote only

# Features
make ls_features                              # List available features
make ls_enabled_features                      # Show enabled features

# Secrets
make settings=SERVER_ID create_cloudflare_token      # Create encrypted token
make settings=SERVER_ID show_cloudflare_token        # Decrypt and show token

# Delta Chat Webhook Bot
make settings=SERVER_ID deploy_webhook               # Full webhook deployment (build, install, configure)
make settings=SERVER_ID build_webhook                # Build Go binary locally
make settings=SERVER_ID create_deltachat_admin       # Create admin account (add to DC client)
make settings=SERVER_ID show_deltachat_admin         # Show admin credentials
make settings=SERVER_ID create_webhook_bot           # Create bot account
make settings=SERVER_ID register_webhook_service SERVICE=name  # Register service: token + DC group
make settings=SERVER_ID show_webhook_token SERVICE=name        # Show Bearer token for calling service
make settings=SERVER_ID webhook_qr SERVICE=name               # Show QR code to invite users to group
make settings=SERVER_ID webhook_invite SERVICE=name            # Get invite link (text)
make settings=SERVER_ID update_webhook_conf                    # Redeploy services.conf + restart
make settings=SERVER_ID ls_webhook_services                    # List all services and their status

# Validation
./scripts/validate_posix.sh                   # Validate POSIX sh compliance
make check                                    # Run validation checks
```

## Template Organization (ADR #0004)

Templates organized by feature:
- `templates/foundation/` - Always generated (core system setup)
- `templates/FEATURE_NAME/` - Optional features enabled via feature flags

Each feature contains stage directories:
- Format: `XNNN-stage-name/` where X=letter (a-z), NNN=3-digit number (001-999)
- Examples: `a001-system-init/`, `e060-nginx/`, `z990-monitoring/`

Within each stage, scripts follow:
- Format: `XNN-script-name.sh` where X=letter (a-z), NN=2-digit number (00-99)
- Examples: `a00-install.sh`, `a10-configure.sh`, `a20-restart.sh`
- Scripts execute in lexicographic order within their stage

## Output Structure (ADR #0003)

Generated scripts in `out/SERVER_ID/` follow staged execution:
- Stages execute in lexicographic order: a001, a010, b020, e060, z990
- Scripts within stages execute in lexicographic order: a00, a10, a20
- Full path: `out/SERVER_ID/XNNN-stage-name/XNN-script-name.sh`

## Feature Flags (ADR #0004, #0005)

Define in `settings/SERVER_ID/server_settings.mk`:

**Format:** `export ENABLE_FEATURE_NAME := VALUE`

**Rules:**
- Values: `1` (enabled) or `0` (disabled) - no other values allowed
- Prefix: Always use `ENABLE_` (never DISABLE_, FEATURE_, etc.)
- Case: UPPERCASE_SNAKE_CASE
- All flags must be explicitly defined (no implicit defaults)

**Examples:**
```makefile
export ENABLE_SWAP := 1        # Enable swap configuration
export ENABLE_NGINX := 0       # Disable nginx
export ENABLE_CHATMAIL := 1    # Enable chatmail server
export ENABLE_NTFY := 0        # Disable push notifications
```

## Shell Scripting Standard (ADR #0012)

**POSIX sh only - NO bash!**

| Use This (POSIX) | NOT This (bash) |
|------------------|-----------------|
| `#!/bin/sh` | `#!/bin/bash` |
| `set -eu` | `set -euo pipefail` |
| `[ condition ]` | `[[ condition ]]` |
| `printf "text\n"` | `echo -e "text"` |
| `. script.sh` | `source script.sh` |
| `while [ $i -lt 10 ]` | `for i in {1..10}` |

**Validation:** `./scripts/validate_posix.sh`

**Reference:** `docs/adr/0012-posix-sh-shell-standard.md` and
`docs/adr/references/posix-sh-reference.md` (full conversion table)

### Heredoc Usage Guidelines

**Rule:** Use heredocs only for short, simple content. For complex or multi-line content,
use external files.

**When to use heredoc:**
- Simple messages or prompts (< 10 lines)
- Basic configuration snippets
- Short SQL queries or commands

**When to use external files:**
- JSON/XML templates (use `.templ` extension)
- Complex configuration (> 10 lines)
- Multi-section content
- Content that needs version control visibility

**File organization:**
- Deployment templates: `templates/FEATURE/STAGE/conf/filename.templ`
- Utility script configs: `scripts/conf/filename.templ`
- Substitution: Use `sed` or template variables (e.g., `TARGET_DOMAIN_PLACEHOLDER`)

**Example:**
```sh
# BAD: Complex JSON in heredoc (40+ lines)
json=$(cat <<EOF
{"complex": "json", "with": ["many", "fields"]}
EOF
)

# GOOD: External file with substitution
script_dir="$(dirname "$0")"
json=$(sed "s/PLACEHOLDER/$value/g" "$script_dir/conf/template.json.templ")
```

**Benefits:** Better readability, easier testing, git diffs show changes clearly,
reusable templates.

## Secrets Management (ADR #0009, #0011)

**Age encryption for all secrets:**
- Create Cloudflare token: `make settings=SERVER_ID create_cloudflare_token`
  - Stores plain token format in `settings/SERVER_ID/cloudflare_token.age`
  - Certbot format auto-generated during `make generate_all_scripts`
- View encrypted token: `make settings=SERVER_ID show_cloudflare_token`
- Local secrets path: Defined in `extended_settings.mk` as `LOCAL_SECRET_PATH`
- Age identity: `$(LOCAL_SECRET_PATH)/age_key_$(SERVER_ID).txt`

**Token formats:**
- Source: `settings/SERVER_ID/cloudflare_token.age` (plain format, used locally)
- Generated: `out/SERVER_ID/secrets/cloudflare_token_nginx.age` (certbot format, deployed to server)

**Rules:**
- Never commit plaintext secrets to version control
- Encrypted .age files are safe to commit
- Use interactive token creation (hidden input, auto-cleanup)
- Single source token, dual format generation (automatic)

## Delta Chat Webhook Bot

### Architecture

One bot account sends messages to Delta Chat groups. One admin account added to groups
for monitoring. Each registered service has a dedicated group and Bearer token.

Accounts and tokens are stored age-encrypted in `settings/SERVER_ID/`:
- `webhook_bot.age` - bot account credentials
- `deltachat_admin.age` - admin account credentials
- `webhook_tokens/NAME.age` - per-service Bearer tokens
- `webhook_groups/NAME.group_id` - per-service Delta Chat group IDs
- `webhook_services.txt` - list of registered service names

### Adding a New Service

```bash
# 1. Add to services file
echo "my-service" >> settings/my_chatmail_server/webhook_services.txt

# 2. Register (creates token + Delta Chat group on server)
make settings=my_chatmail_server register_webhook_service SERVICE=my-service

# 3. Push updated config to server + restart
make settings=my_chatmail_server update_webhook_conf

# 4. Invite users to the group (scan QR with Delta Chat)
make settings=my_chatmail_server webhook_qr SERVICE=my-service

# 5. Get token for the calling service
make settings=my_chatmail_server show_webhook_token SERVICE=my-service
```

### Sending a Notification

```bash
curl -X POST https://deltachat.example.org/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "deploy succeeded on prod"}'
```

**Known gotcha:** `register_webhook_service` and `webhook_invite` stop/start the service
to release the deltachat-rpc-server accounts dir lock. Brief outage (~2s) expected.

**Reference:** ADR #0028 (`docs/adr/0028-deltachat-webhook-bot.md`)

## Version Control System

**This project uses Fossil, NOT Git.**

### Fossil Commands

```bash
fossil timeline -v -n 1000    # View history (last 1000 commits)
fossil status                 # Check status
fossil addremove              # Auto-detect new/deleted files
fossil add FILE               # Stage specific file
fossil commit -m "message"    # Commit changes
fossil diff                   # View changes
fossil ui                     # Web UI (graphical interface)
fossil undo                   # Undo last checkout
fossil info HASH              # Commit details
```

### Fossil Commit Message Style

**Use Fossil style (descriptive, full sentences, periods):**

```
Deploy Delta Chat webhook bot for my_chatmail_server.

Go binary wraps deltachat-rpc-server; each service gets its own
Bearer token and dedicated group. Deployment fully automated via
make deploy_webhook.
```

**NOT Git conventional commits style:**

```
feat: add webhook bot deployment

- add deploy_webhook target
- register 3 services
```

**Key differences:**
- Fossil: Full sentences, periods, paragraph format, natural language
- Fossil: No prefixes (feat:, fix:, refactor:, chore:)
- Fossil: Focus on "what and why" - can be more verbose
- Git: Imperative mood, no periods, bullet lists, prefixes

## ADR Guidelines

**Follow:** `docs/claude/adr-guidelines.md`

### Mandatory Requirements

- Keep each ADR under 150 lines (target: 100-120 lines)
- Include sections: Summary (TL;DR), Quick Reference, Context, Decision, Consequences, Alternatives, References
- Use tables over prose wherever possible
- Frontload critical info (Summary first!)
- Move examples >20 lines to `docs/adr/references/`
- Limit to top 3 alternatives (move extras to references)

### Token Efficiency

- Concrete file paths: `templates/nginx/e060-nginx/a00-install.sh`
- NOT abstract: "the nginx installation script"
- Commands in backticks: `make check`, `./scripts/validate.sh`
- Numbers over words: "8 files changed" not "several files"

### Storage

- ADRs: `docs/adr/NNNN-title.md`
- References: `docs/adr/references/topic-name.md`
- Index: Update `docs/adr/0000-index.md` for each new ADR
- Create ADR for all architectural decisions
- Document research findings in ADR files

## Model Instructions

### Code Style

- Follow best software development guidelines
- Prefer clarity over cleverness
- Limit lines to 120 characters
- Use concrete examples, not placeholders

### Preferred Tools

- make, sh (not bash), awk, age, jq
- rclone (if remote access needed beyond ssh)
- rsync, ssh (for deployment)

### File Generation Rules

**When generating/editing files:**

1. Set author to `vld.lazar@proton.me`
2. Add remark: `generated/edited with Claude`
3. Set copyright to `vld.lazar@proton.me`
4. **USE ASCII ONLY** - Critical rule!
   - No unicode, emoji, or fancy characters
   - Checkmarks: Use "OK" not tick marks (not: OK X)
   - Bullets: Use "-" or "*" not arrows/stars (not: ->)
   - Exception: Only when absolutely necessary for functionality, NOT decoration

### User Request Logging

**IMPORTANT: Log all user requests for project continuity and review.**

**Rules:**
- Create daily log file: `docs/user-requests/YYYY-MM-DD.md`
- Log each request with approximate time
- Store full request text with cleaned formatting and corrected typos
- Keep format simple: markdown with headers per request
- Include brief action summary for each request

**File format:**
```markdown
# User Requests Log - YYYY-MM-DD

## Request 1
**Time:** HH:MM
[Full user request text]
**Action:** Brief summary of what was done

## Request 2
**Time:** HH:MM
[Full user request text]
**Action:** Brief summary of what was done
```

**When to update:**
- After each user request during session
- At end of session as minimum
- Keep file open and append throughout day

### Validation & Testing

Before committing:
- POSIX compliance: `./scripts/validate_posix.sh`
- Feature flags: Verify all ENABLE_* are 0 or 1
- ADR compliance: Under 150 lines, includes Summary + Quick Reference
- Test generated scripts: `make settings=SERVER_ID deploy_check`

## Key Files Reference

| File | Purpose | Key Info |
|------|---------|----------|
| `Makefile` | Main automation | deploy, webhook, chatmail targets |
| `settings/SERVER_ID/server_settings.mk` | Server config | Feature flags, HOST_IP, SERVER_ID |
| `settings/SERVER_ID/extended_settings.mk` | Deployment config | SSH keys, secrets paths, deploy settings |
| `settings/SERVER_ID/cloudflare_token.age` | Encrypted secret | Cloudflare API token (Age encrypted) |
| `docs/adr/0000-index.md` | ADR index | Read first! Lists all decisions |
| `docs/claude/adr-guidelines.md` | ADR rules | Writing standards, formatting |
| `docs/claude/PROJECT_NOTES.md` | Current work | Session continuity, active tasks |
| `docs/user-requests/YYYY-MM-DD.md` | Request logs | Daily log of user requests with timestamps |
| `scripts/validate_posix.sh` | Validation | Check POSIX sh compliance |
| `src/deltachat-webhook/` | Webhook bot source | Go binary, build with make build_webhook |

## Reference Documents by Topic

| Topic | Main ADR | Reference File |
|-------|----------|----------------|
| POSIX sh standard | ADR #0012 | `docs/adr/references/posix-sh-reference.md` |
| Staging structure | ADR #0003 | `docs/adr/references/staging-structure-examples.md` |
| Feature generation | ADR #0004 | `docs/adr/references/feature-generation-examples.md` |
| Feature flags | ADR #0005 | `docs/adr/references/feature-flag-examples.md` |
| Deployment automation | ADR #0010 | `docs/adr/references/deployment-workflows.md` |
| Cloudflare tokens | ADR #0011 | `docs/adr/references/cloudflare-token-workflows.md` |
| Delta Chat webhook | ADR #0028 | `docs/adr/0028-deltachat-webhook-bot.md` |
| Chatmail server | ADR #0026 | `docs/adr/0026-deltachat-chatmail-server.md` |

## Workflow Examples

### Adding a New Feature

1. Create template directory: `mkdir -p templates/FEATURE/XNNN-stage-name/`
2. Add scripts: `templates/FEATURE/XNNN-stage-name/XNN-script.sh` (use POSIX sh!)
3. Add feature flag to all `settings/*/server_settings.mk`: `export ENABLE_FEATURE := 0`
4. Add conditional to Makefile (if optional feature)
5. Enable for specific servers: Change flag to `1` in their `server_settings.mk`
6. Generate and test: `make settings=SERVER_ID generate_all_scripts`
7. Validate: `./scripts/validate_posix.sh`

### Writing an ADR

1. Check index: `docs/adr/0000-index.md` to avoid duplicates
2. Create file: `docs/adr/NNNN-title.md` (next sequential number)
3. Include: Summary, Quick Reference, Context, Decision, Consequences, Alternatives, References
4. Keep under 150 lines - move examples to `docs/adr/references/` if needed
5. Update index: Add entry to `docs/adr/0000-index.md`
6. Use tables for comparisons, concrete file paths, commands in backticks

### Deploying to Server

1. Generate: `make settings=SERVER_ID generate_all_scripts`
2. Validate: `./scripts/validate_posix.sh`
3. Dry-run: `make settings=SERVER_ID deploy_check`
4. Deploy: `make settings=SERVER_ID deploy`
5. Or manual: Copy scripts, SSH to server, run `./a001-run-all/run-all.sh`
