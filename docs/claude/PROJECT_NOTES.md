# MDIST-LIGHT Project Notes

Author: vld.lazar@proton.me
Last Updated: 2026-04-20
Purpose: Track work-in-progress, current tasks, and session continuity

---

## Current State - 2026-04-20

### S03 DeltaChat Server (my_chatmail_server)

**Status: Fully operational.**

| Component | Status | Notes |
|-----------|--------|-------|
| Postfix | Running | SMTP with filtermail content filter |
| Dovecot | Running | IMAP, SASL auth for Postfix |
| opendkim | Running | Socket at /var/spool/postfix/opendkim/opendkim.sock |
| filtermail | Running | Outbound + incoming content filter |
| nginx | Running | TLS, /new CGI, port 443 IMAP/SMTP ALPN proxy |
| ntfy | Running | Push notifications |
| Let's Encrypt | Valid | deltachat.example.org |

**Key facts:**
- Invite-only: tokens in `settings/my_chatmail_server/chatmail_tokens/`
- Invite URL format: `DCACCOUNT:https://deltachat.example.org/new?token=TOKEN`
- Custom newemail.py deployed to `/usr/lib/cgi-bin/newemail.py`
- cmdeploy tests pass: `cd ~/src/chatmail-relay && python -m pytest cmdeploy/src/cmdeploy/tests/online/test_1_basic.py`
- PTR record set: 203.0.113.1 -> deltachat.example.org

**Known gotcha:** If server is rebooted during a SecureJoin key exchange, the chat gets
stuck in "establishing connections". Fix: re-scan QR code.

**Gmail federation:** Fully working as of 2026-04-19.
- Correct invite flow: generate QR on example.org Delta Chat, scan with Gmail client (iPhone)
- SecureJoin completes in ~5 seconds, chat appears on both sides

**Makefile fix applied:** chatmail_disable_resolved_stub now writes static /etc/resolv.conf
(nameserver 127.0.0.1) instead of symlink to systemd-resolved. Prevents filtermail-incoming
DNS crash after reboot.

---

## Current State - 2026-04-20

### Delta Chat Webhook Bot (my_chatmail_server)

**Status: Fully operational.**

Go binary that accepts HTTP webhook POST requests and delivers messages to
pre-configured Delta Chat groups via deltachat-rpc-server.

| File | Purpose |
|------|---------|
| `src/deltachat-webhook/` | Go source, build with `make build_webhook` |
| `settings/my_chatmail_server/webhook_bot.age` | Bot account credentials |
| `settings/my_chatmail_server/deltachat_admin.age` | Admin account credentials |
| `settings/my_chatmail_server/webhook_services.txt` | Registered service names |
| `settings/my_chatmail_server/webhook_tokens/<name>.age` | Per-service auth tokens |
| `settings/my_chatmail_server/webhook_groups/<name>.group_id` | Per-service group IDs |

**Architecture:**
- One bot account + one admin account (both created via chatmail invite tokens)
- Each service: Bearer token -> Delta Chat group (1:1 mapping)
- HTTP endpoint: `POST https://deltachat.example.org/webhook`
- Binary subcommands: serve, create-group, invite, add-member

**Deployed 2026-04-20. All components operational.**

| Component | Status | Notes |
|-----------|--------|-------|
| deltachat-rpc-server | Installed | /usr/local/bin, v2.49.0 |
| deltachat-webhook | Running | systemd service, /opt/deltachat-webhook/ |
| nginx /webhook | Active | proxies to 127.0.0.1:8095 |
| Bot account | Configured | bot-account@deltachat.example.org |
| Admin account | Configured | admin-account@deltachat.example.org |
| test-service-a | Registered | group 12, 2 users joined |
| test-service-b | Registered | group 13 |
| test-service-c | Registered | group 14 |

**Known gotcha:** `register_webhook_service` and `webhook_invite` stop/start the service
to release the deltachat-rpc-server accounts dir lock. Brief outage (~2s) expected.

**Key commands:**
```bash
# Full deployment (idempotent)
make settings=my_chatmail_server deploy_webhook

# Add a new service
echo "svc" >> settings/my_chatmail_server/webhook_services.txt
make settings=my_chatmail_server register_webhook_service SERVICE=svc
make settings=my_chatmail_server update_webhook_conf

# Invite users to a group (show QR code, scan with Delta Chat)
make settings=my_chatmail_server webhook_qr SERVICE=svc

# Get Bearer token for a service
make settings=my_chatmail_server show_webhook_token SERVICE=svc

# List all services
make settings=my_chatmail_server ls_webhook_services
```

**Send a notification:**
```bash
curl -X POST https://deltachat.example.org/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "message"}'
```

**Reference:** ADR #0028 (`docs/adr/0028-deltachat-webhook-bot.md`)

---

## Key Commands

```bash
# Generate scripts
make settings=my_chatmail_server generate_all_scripts

# Full deploy
make settings=my_chatmail_server deploy

# Deploy webhook bot only
make settings=my_chatmail_server deploy_webhook

# Validate
./scripts/validate_posix.sh
```

---

## Session Continuity Instructions

For next session:
1. Run `make claude_start` for reminder
2. Read this file
3. Read `docs/user-requests/YYYY-MM-DD.md` for recent requests
4. Check `fossil timeline -n 5` for recent commits
5. All services running, webhook bot operational
