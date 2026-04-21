# ADR #0026: Delta Chat Chatmail Server

Author: vld.lazar@proton.me
Status: Accepted
Generated/edited with Claude

## Summary (TL;DR)

Deploy a Delta Chat chatmail relay on S03 using the upstream `chatmail/relay` project
instead of custom MDIST templates. MDIST wraps `cmdeploy` via Makefile targets and
stores `chatmail.ini` in the settings directory.

## Quick Reference

```sh
# One-time setup
make settings=my_chatmail_server chatmail_setup_env
make settings=my_chatmail_server chatmail_init
# -> copy chatmail.ini to settings/my_chatmail_server/chatmail.ini

# Deploy / update
make settings=my_chatmail_server deploy_chatmail

# Operations
make settings=my_chatmail_server chatmail_dns     # DNS records to add
make settings=my_chatmail_server chatmail_status  # service health
make settings=my_chatmail_server chatmail_test    # functional test
```

**chatmail.ini:** `settings/my_chatmail_server/chatmail.ini` (committed to repo)
**Local relay repo:** `~/src/chatmail-relay` (defined in `chatmail_relay_dir`)

## Context

chatmail/relay (https://github.com/chatmail/relay) is the upstream deployment tool for
Delta Chat chatmail servers. It installs and configures the full stack automatically:
Postfix, Dovecot, filtermail (E2EE enforcement), OpenDKIM, nginx, acmetool (TLS),
Iroh relay (P2P), TURN, push notifications (chatmaild services).

Building this from scratch in MDIST shell templates would duplicate all that work
without the benefit of upstream maintenance, and would omit chatmail-specific
components (filtermail, doveauth auto-provisioning, chatmail-expire, Iroh relay).

## Decision

MDIST provides a thin wrapper around `cmdeploy` rather than custom templates.

| Component | Managed by |
|-----------|-----------|
| Postfix, Dovecot, nginx, TLS | chatmail/relay (cmdeploy) |
| filtermail, doveauth, chatmaild | chatmail/relay (cmdeploy) |
| OpenDKIM, Iroh relay, TURN | chatmail/relay (cmdeploy) |
| chatmail.ini config | MDIST settings directory |
| ntfy notifications | MDIST (templates/ntfy/) |
| Server baseline (swap, tools) | MDIST (foundation templates) |

User accounts are **auto-created on first Delta Chat login** (chatmail doveauth semantics).
No manual user provisioning needed.

## Consequences

- `chatmail/relay` must be cloned locally: `~/src/chatmail-relay`
- Python 3 and `rsync` required on build machine
- `chatmail.ini` stored in `settings/my_chatmail_server/` and committed
- DNS records: use `make chatmail_dns` to get the exact records after deploy
- TLS managed by acmetool (not certbot) - ntfy cert also via acmetool (see ADR #0027)
- Account creation is automatic (chatmail design) - no Makefile targets for users

## Alternatives

- **Custom Postfix+Dovecot templates** - rejected: would miss filtermail, doveauth,
  chatmail-expire, Iroh relay, and require ongoing maintenance to track upstream.

## References

- `docs/adr/0027-ntfy-webhook-notifications.md`
- https://chatmail.at/doc/relay/ - full documentation
- https://github.com/chatmail/relay - source
