# 0006 — Automated NGINX Provisioning
Date: 2025-11-01
Status: Accepted
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: Web service maintainers, security reviewers
Informed: System administrators, template contributors
Tags: web, automation, templates, nginx

## Context

Servers such as `my_chatmail_server` that need NGINX for proxying and static assets, yet the project has no automated
template for installation or configuration. Manual setups drift, skip security hardening, and break the feature-flag
workflow established in ADR 0004/0005 and the staged output layout from ADR 0003.

## Decision

Add an `nginx` feature directory at `templates/nginx/e060-nginx/` that only generates when `export ENABLE_NGINX := 1` is
set in `server_settings.mk`. The feature yields two ordered scripts:
- `a00-install_nginx.sh` installs packages, strips default sites, creates content dirs, and hardens the service.
- `a10-configure_nginx.sh` renders virtual-host templates using `template_subst.sh`, writes to `/etc/nginx/sites-*`,
  validates with `nginx -t`, and reloads the unit.
Scripts follow the standard Bash conventions (`#!/bin/bash`, `set -euo pipefail`, prefixed ordering) and can be extended
with optional subordinate flags (e.g., `ENABLE_NGINX_ACME`) when needed.

## Consequences

### Positive
- Consistent provisioning and hardened defaults for every NGINX host.
- Aligns with feature flags (ADR 0005) and stage ordering (ADR 0003).
- Templates surface in `out/<server_id>/e060-nginx/` for review before deployment.
- Easy to add additional scripts without touching unrelated features.

### Negative
- Template maintenance must track distro package and path changes.
- Supporting complex multi-site configs increases variable sprawl.
- Stage placement (`e060`) encodes ordering; moving it requires renumbering.

### Risks/Trade-offs
- Misconfigured `NGINX_*` settings can fail validation; mitigated by `nginx -t`.
- Forgetting to set `ENABLE_NGINX` leaves hosts unprovisioned; validation tooling may be needed.
- TLS assets remain an external dependency unless future scripts add ACME support.

## Follow-up
- Document required `NGINX_*` variables in contributor guides.
- Add placeholders to relevant `extended_settings.mk` files.
- Implement scripts and Makefile wiring for the `nginx` feature.
- Review TLS/ACME automation needs and model follow-on ADRs if required.
