# ADR #0028: Delta Chat Webhook Bot

**Status:** Accepted
**Date:** 2026-04-19
**Deployed:** 2026-04-20

## Summary (TL;DR)

HTTP webhook endpoint that delivers notifications to Delta Chat groups.
A Go binary wraps `deltachat-rpc-server` (official chatmail RPC server).
Multiple services, each with own auth token and dedicated group.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `make deploy_webhook` | Full deployment (build, install, configure, start) |
| `make build_webhook` | Build Go binary locally |
| `make create_deltachat_admin` | Create admin account (add to DC client) |
| `make show_deltachat_admin` | Show admin credentials |
| `make create_webhook_bot` | Create bot account |
| `make register_webhook_service SERVICE=name` | Register service: token + DC group |
| `make show_webhook_token SERVICE=name` | Show Bearer token for calling service |
| `make webhook_qr SERVICE=name` | Show QR code to invite users to group |
| `make webhook_invite SERVICE=name` | Get invite link (text) |
| `make update_webhook_conf` | Redeploy services.conf + restart (after adding services) |
| `make ls_webhook_services` | List all services and their status |

Webhook call:
```
POST https://deltachat.example.org/webhook
Authorization: Bearer <token>
Content-Type: application/json
{"text": "notification message"}
```
Returns HTTP 204 on success.

## Workflows

### Adding a new service

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

### Inviting users to a group

Users join via SecureJoin (E2E key exchange). They need a Delta Chat account.

```bash
make settings=my_chatmail_server webhook_qr SERVICE=my-service
# -> prints QR code in terminal
# -> user scans with Delta Chat -> added to group in ~5 seconds
```

Note: pasting the https://i.delta.chat/# URL directly into DC does not work.
Users must scan the QR code or open the URL in a mobile browser (deep-links to DC).

### Sending a notification

```bash
curl -X POST https://deltachat.example.org/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "deploy succeeded on prod"}'
```

## Context

Services need to send status notifications to Delta Chat groups.
Chatmail servers enforce E2E encryption -- plain SMTP is insufficient.
Must use a real Delta Chat account that handles key exchange via Autocrypt.

## Decision

**Go binary** (`src/deltachat-webhook/`) with subcommands:
- `serve` -- HTTP webhook server (runs as systemd service)
- `create-group` -- create Delta Chat group, add admin member
- `invite` -- get invite link for a group
- `add-member` -- add member to group

**Two special accounts** created via existing chatmail invite tokens:
- Bot account: sends messages, creates groups, stored in `webhook_bot.age`
- Admin account: added to every group (where key exchange allows), stored in
  `deltachat_admin.age`. Users manage group membership via DC app.

**JSON-RPC** communication with `deltachat-rpc-server` (subprocess via stdin/stdout).
No external Go dependencies -- own RPC client (rpc.go, ~140 lines).

**Config files on server** (`/opt/deltachat-webhook/`):
- `bot.conf` -- bot credentials (address + password, chmod 600)
- `services.conf` -- one line per service: `name token group_id` (chmod 600)

**Token to group routing:** each Bearer token maps to one group_id in services.conf.

## File Structure

```
src/deltachat-webhook/    - Go source (main.go, bot.go, rpc.go, config.go, serve.go)
settings/SERVER_ID/
  deltachat_admin.age     - admin account credentials (age-encrypted)
  webhook_bot.age         - bot account credentials (age-encrypted)
  webhook_services.txt    - registered service names (one per line)
  webhook_tokens/NAME.age - per-service auth tokens (age-encrypted)
  webhook_groups/NAME.group_id - per-service Delta Chat group IDs
```

## Server State (deployed 2026-04-20)

| Item | Value |
|------|-------|
| Binary | /opt/deltachat-webhook/deltachat-webhook |
| Accounts dir | /var/lib/deltachat-webhook/ |
| Config dir | /opt/deltachat-webhook/ |
| Listen | 127.0.0.1:8095 |
| Nginx location | /webhook on deltachat.example.org |
| Systemd service | deltachat-webhook.service |
| deltachat-rpc-server | /usr/local/bin/deltachat-rpc-server v2.49.0 |
| Bot account | bot-account@deltachat.example.org |
| Admin account | admin-account@deltachat.example.org |

## Consequences

- deltachat-rpc-server holds accounts dir lock while serve is running
- Management commands (register_webhook_service, webhook_invite, webhook_qr) stop the
  service briefly (~2s) to release the lock, then restart it
- Bot account must be a member of each notification group
- Groups survive reboots (state stored in deltachat-rpc-server accounts dir)
- If bot is removed from group: run `make webhook_invite`, re-join via QR
- Delta Chat groups have no admin enforcement -- all members equal
- Admin pre-add to groups fails on fresh accounts ("Only key-contacts can be added
  to encrypted chats") -- admin joins via invite link same as regular users

## Alternatives

**deltachat-webhook-bot (Go, jgimenez):** text-only, no group support -- rejected.

**deltabot-cli-py (Python):** requires Python + venv on server -- rejected.

**Plain SMTP:** chatmail servers enforce E2E encryption -- rejected.

## References

- `src/deltachat-webhook/` -- Go source
- `docs/adr/0026-deltachat-chatmail-server.md` -- chatmail server setup
- deltachat-rpc-server: https://github.com/chatmail/core/tree/main/deltachat-rpc-server
