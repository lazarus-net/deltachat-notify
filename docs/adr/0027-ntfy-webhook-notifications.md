# ADR #0027: ntfy Webhook Notification Server

Author: vld.lazar@proton.me
Status: Accepted
Generated/edited with Claude

## Summary (TL;DR)

Self-hosted ntfy server on `ntfy.example.org` for sending push notifications via HTTP POST.
Runs as `ENABLE_NTFY := 1` on the deltachat S03 server, proxied through NGINX.

## Quick Reference

| Item | Value |
|------|-------|
| Tool | ntfy (binwiederhier/ntfy) |
| Domain | `ntfy.example.org` |
| Internal port | 8090 |
| Templates | `templates/ntfy/g070-ntfy/` |
| Config | `/etc/ntfy/server.yml` |

**Send notification:**
```sh
curl -d "Deploy complete" -H "Authorization: Bearer TOKEN" https://ntfy.example.org/alerts
```

**Manage:**
```sh
make settings=my_chatmail_server create_ntfy_token TOPIC=alerts
make settings=my_chatmail_server show_ntfy_tokens
```

## Context

The server needs a simple mechanism to send push notifications from scripts or external
webhooks (CI/CD, monitoring, cron jobs). ntfy is a lightweight Go binary with:
- HTTP pub/sub API (POST = publish, GET/SSE = subscribe)
- Mobile apps (Android/iOS) for push delivery
- Web UI for browsing topics
- Token-based auth per topic

## Decision

Single stage `g070-ntfy` under `ENABLE_NTFY := 1`:

| Script | Purpose |
|--------|---------|
| `a00-install.sh` | Download binary from GitHub releases |
| `a10-configure.sh` | Deploy server.yml + systemd unit |
| `a15-nginx-vhost.sh` | Deploy NGINX reverse proxy vhost |
| `a20-restart.sh` | Enable and start service |

**Auth:** `auth-default-access: deny-all` - every topic requires a token.
Tokens created via `make settings=XXXX create_ntfy_token TOPIC=name`.

**TLS:** Uses same Let's Encrypt cert as main domain (`letsencrypt_domain` SAN includes
`ntfy.example.org` via `letsencrypt_additional_domains`).

**Proxy:** ntfy runs on `localhost:8090`, NGINX terminates TLS and proxies with
WebSocket/SSE support (long-lived connections for real-time push).

## Consequences

- `ntfy.example.org` must have an A record pointing to 203.0.113.1.
- NGINX must be deployed before ntfy (cert required for vhost).
- ntfy mobile app can subscribe to topics for push notifications.

## Alternatives

- **Gotify** - similar but Android-only push, no SSE API. Rejected: ntfy is simpler.
- **Apprise** - notification library, not a server. Different use case.
- **Email notifications** - available via Delta Chat on same server but heavier.

## References

- `docs/adr/0026-deltachat-chatmail-server.md` - server context
- https://docs.ntfy.sh - ntfy documentation
