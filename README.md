# deltachat-notify

Author: vld.lazar@proton.me
Copyright (C) 2026 vld.lazar@proton.me

Makefile-based server automation for a Delta Chat chatmail server with webhook
notification bot. Simplified version of cdist.

## What it does

Automates deployment and management of:

- **Delta Chat chatmail server** -- invite-only E2E-encrypted messaging via the
  upstream `chatmail/relay` project (Postfix, Dovecot, filtermail, OpenDKIM,
  nginx, TLS, push notifications)
- **ntfy** -- push notification server
- **deltachat-webhook** -- HTTP webhook bot that delivers messages to Delta Chat
  groups; services authenticate with Bearer tokens

## Prerequisites

| Tool | Purpose |
|------|---------|
| `make` | Build and deploy automation |
| `age` | Secret encryption/decryption |
| `go` | Build webhook bot binary |
| `ssh` | Remote deployment |
| `python3`, `python3-venv`, `python3-dev`, `gcc` | chatmail/relay cmdeploy |
| `qrencode` | Show invite QR codes in terminal |
| `jq` | JSON processing |

## Quick Start

### 1. Configure your server

Copy the example settings directory and edit it:

```sh
cp -r settings/my_chatmail_server settings/my_server
```

Edit `settings/my_server/server_settings.mk`:
```makefile
export SERVER_ID=my_server
export HOST_NAME=deltachat.yourdomain.com
export HOST_IP=1.2.3.4
export ADMIN_EMAIL=you@example.com
```

Edit `settings/my_server/extended_settings.mk`:
```makefile
export deploy_ssh_identity := /home/you/.ssh/id_ed25519
export chatmail_domain     := deltachat.yourdomain.com
export ntfy_domain         := ntfy.yourdomain.com
```

Edit `settings/my_server/chatmail.ini` -- set `mail_domain` to your chatmail domain.

If you use Cloudflare DNS, create an encrypted DNS token (used for DNS record
automation and Let's Encrypt):

```sh
make settings=my_server create_cloudflare_token
```

### 2. Deploy the chatmail server

```sh
make settings=my_server deploy_chatmail
```

This single command: clones chatmail/relay if needed, creates the age key and
recipients file if missing, sets up SSH config, creates/verifies Cloudflare DNS
records, waits for DNS to propagate, and runs cmdeploy on the server.

Verify afterwards:

```sh
make settings=my_server chatmail_status
make settings=my_server chatmail_test
```

### 3. Deploy the webhook bot

Add your notification services to `settings/my_server/webhook_services.txt`
(one name per line), then:

```sh
make settings=my_server deploy_webhook
```

This builds the Go binary, creates bot and admin Delta Chat accounts, registers
all services from webhook_services.txt (each gets a token and a group), deploys
everything to the server, and starts the systemd service.

Invite users to a group and get the Bearer token:

```sh
make settings=my_server webhook_qr SERVICE=my-service    # scan QR with Delta Chat
make settings=my_server show_webhook_token SERVICE=my-service
```

### 4. Send a notification

```sh
curl -X POST https://deltachat.yourdomain.com/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "deploy succeeded"}'
```

Returns HTTP 204 on success. Message is delivered to the Delta Chat group.

## Adding a Service Later

```sh
echo "new-service" >> settings/my_server/webhook_services.txt
make settings=my_server register_webhook_service SERVICE=new-service
make settings=my_server update_webhook_conf

make settings=my_server webhook_qr SERVICE=new-service
make settings=my_server show_webhook_token SERVICE=new-service
```

## Common Commands

```sh
make settings=SERVER help                 # Show all available commands
make settings=SERVER ls_settings          # Show current configuration
make settings=SERVER deploy_chatmail      # Deploy/update chatmail server
make settings=SERVER deploy_webhook       # Deploy/update webhook bot
make settings=SERVER chatmail_status      # Check service health
make settings=SERVER chatmail_test        # Run functional tests
make settings=SERVER ls_webhook_services  # List registered services
./scripts/validate_posix.sh              # Validate POSIX sh compliance
```

## Project Structure

```
Makefile                    - All automation targets
settings/my_server/         - Per-server configuration and encrypted secrets
  server_settings.mk        - Feature flags, HOST_IP, SERVER_ID
  extended_settings.mk      - SSH keys, domain names, service settings
  chatmail.ini              - chatmail/relay configuration (committed)
  chatmail_tokens/          - Age-encrypted invite tokens
  webhook_bot.age           - Bot account credentials
  deltachat_admin.age       - Admin account credentials
  webhook_tokens/NAME.age   - Per-service Bearer tokens
  webhook_groups/NAME.group_id - Per-service Delta Chat group IDs
  webhook_services.txt      - List of registered service names
src/deltachat-webhook/      - Go source for webhook bot binary
templates/                  - Deployment script templates
  foundation/               - Always deployed (swap, tools, age identity)
  ntfy/                     - ntfy push notification server
scripts/                    - Utility scripts (POSIX sh)
docs/adr/                   - Architecture Decision Records
```

## Secrets

All secrets are encrypted with [age](https://age-encryption.org/). Encrypted
`.age` files are safe to commit. The age key and recipients file are created
automatically on first use. Plaintext secrets never persist to disk.

## Architecture Decisions

See `docs/adr/0000-index.md` for the full list. Key decisions:

| ADR | Decision |
|-----|----------|
| #0026 | Use upstream `chatmail/relay` instead of custom templates |
| #0027 | ntfy for push notifications |
| #0028 | Go binary webhook bot wrapping deltachat-rpc-server |
| #0012 | POSIX sh only in all shell scripts |
| #0010 | Remote deployment via SSH + rsync |
