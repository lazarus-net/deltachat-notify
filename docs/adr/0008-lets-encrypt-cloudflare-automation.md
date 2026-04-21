# 0008 — Let's Encrypt Automation Behind Cloudflare
Date: 2025-11-01
Status: Amended
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: repository operators, web platform maintainers
Informed: automation contributors, security reviewers
Tags: tls, automation, nginx, cloudflare

## Context
The nginx feature provisions proxy and static hosting, but operators still enroll TLS certificates manually. For hosts
proxied by Cloudflare, HTTP-01 challenges fail, and ad-hoc instructions produce inconsistent credentials handling. We
need an automated, repeatable path that respects Cloudflare's DNS-01 flow while keeping secrets out of version control
and integrating with the existing staged script execution.

## Decision
Add `templates/nginx/e060-nginx/a05-request_letsencrypt.sh`, positioned between package install and nginx configuration.
The script installs certbot with the Cloudflare DNS plugin, writes the provided API token to
`letsencrypt_cloudflare_credentials_path` with `0600` permissions, then requests/renews certificates using
`certbot certonly --keep-until-expiring`. New settings keys in `extended_settings.mk` capture domain, SANs, notification
email, propagation wait, staging toggle, and API token. Runtime documentation lives in `docs/letsencrypt-cloudflare.md`
so operators understand prerequisites and secret management. Amended by ADR 0009 to use Age-encrypted token storage.

## Consequences
- Positive: TLS issuance becomes reproducible and idempotent, aligning with nginx deployment automation and reducing
  manual certificate handling.
- Negative: Requires storing the Cloudflare API token in server-local configuration; operators must rotate secrets if
  they regenerate scripts from shared workstations.
- Risks/Trade-offs: Misconfigured propagation timing can cause transient failures; the process still assumes Ubuntu
  packages for certbot.
- Follow-up work: Consider integrating ACME account key storage or deploying dehydrated for environments without apt.

## Alternatives
- Continue manual certificate provisioning — rejected: inconsistent and undocumented, risking expired certs.
- Use HTTP-01 challenge through temporary firewall changes — rejected: Cloudflare proxy prevents direct validation, and
  disabling the proxy undermines automation goals.

## References
- `templates/nginx/e060-nginx/a05-request_letsencrypt.sh`
- `docs/letsencrypt-cloudflare.md`
- Certbot DNS Cloudflare: https://certbot-dns-cloudflare.readthedocs.io/
