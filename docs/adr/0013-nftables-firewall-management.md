# 0013 - nftables Firewall Management

Date: 2025-11-06
Status: Accepted
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: Debian documentation, nftables maintainers
Informed: Server operators, deployment teams
Tags: security, firewall, nftables, nginx

## Summary

Replaced UFW-based firewall configuration with nftables in NGINX installation script.
nftables is the default firewall framework in Debian 11+ (Bookworm), built into the kernel,
and provides modern packet filtering without additional packages. Script creates inet filter
table with input/forward/output chains, allows SSH/HTTP/HTTPS ports, and saves rules
persistently. Implementation is idempotent and safe to re-run.

## Quick Reference

| Item | Value |
|------|-------|
| **Script** | `templates/nginx/e060-nginx/a00-install_nginx.sh` (lines 94-159) |
| **Commands** | `nft list ruleset`, `nft add rule inet filter input tcp dport 443 accept` |
| **Service** | `systemctl enable --now nftables` |
| **Rules file** | `/etc/nftables.d/mdist-nginx.nft` |
| **Table** | `inet filter` (handles both IPv4 and IPv6) |

## Context

Previous implementation checked for UFW and skipped firewall configuration if not present.
Debian 10+ ships with nftables as the default firewall framework, replacing iptables.
nftables is built into the kernel, requires no additional packages, and is more efficient
than legacy iptables. UFW requires installation and adds an abstraction layer.

**Requirements:** Secure server by allowing only required ports, use native Debian tools,
maintain SSH access during setup, support both HTTP and HTTPS, be idempotent for re-runs.

## Decision

Use nftables directly for firewall management instead of UFW or iptables.

**Implementation details:**
- Create `inet filter` table (handles IPv4 and IPv6 simultaneously)
- Establish three chains: input (policy drop), forward (policy drop), output (policy accept)
- Base rules: Allow loopback, established/related connections, SSH port 22, ICMP ping
- Dynamic rules: Add HTTP port (if configured) and HTTPS port from settings
- Idempotent checks: Verify table exists before creating, check rules exist before adding
- Persistence: Enable nftables service, save rules to `/etc/nftables.d/`

**Safety measures:**
- SSH port 22 allowed before any other rules to prevent lockout
- Check if rules already exist before adding to support re-runs
- Use `systemctl enable --now` to ensure rules persist across reboots
- Install nftables package only if not already present

## Key Changes

- `templates/nginx/e060-nginx/a00-install_nginx.sh:94-159`: Replaced `configure_firewall()`
- Removed: UFW dependency check
- Added: nftables installation and configuration
- Added: inet filter table creation with default policies
- Added: Base security rules (loopback, established, SSH, ping)
- Added: HTTP/HTTPS port rules based on extended_settings.mk variables
- Added: Idempotent rule checking with grep
- Added: Rule persistence to /etc/nftables.d/

## Consequences

**Positive:**
- Native Debian solution, no extra packages needed (nftables built-in)
- Single framework for both IPv4 and IPv6 (inet table)
- More efficient than iptables (better performance on high-traffic servers)
- Idempotent script execution (safe to re-run)
- Persistent rules across reboots (via systemctl enable)
- Clear security model (default deny input, explicit allows)
- SSH protection (always allowed first to prevent lockout)

**Negative:**
- More complex syntax than UFW
- Requires learning nftables commands for troubleshooting
- Initial table creation uses "policy drop" (could lock out if SSH rule fails)

**Risks:**
- Potential SSH lockout if script fails mid-execution (mitigated by adding SSH rule first)
- Existing firewall rules could conflict (script creates new table, may need manual cleanup)
- grep-based rule checking is fragile (could miss rules with different formatting)

**Follow-up work:**
- Consider creating dedicated nftables configuration template file
- Add rollback mechanism if firewall setup fails
- Implement more robust rule existence checking
- Add support for custom port ranges
- Document manual nftables troubleshooting steps

## Alternatives

**Option A: Continue with UFW**
- Pro: Simpler syntax, easier to understand
- Con: Requires additional package installation, abstraction layer overhead
- Rejected: Not native to Debian, adds unnecessary dependency

**Option B: Use iptables-nft (compatibility layer)**
- Pro: Familiar iptables syntax, uses nftables backend
- Con: Deprecated compatibility mode, not recommended for new deployments
- Rejected: Debian moving away from iptables, should use native nftables

**Option C: No firewall management**
- Pro: Simpler script, no security assumptions
- Con: Leaves server exposed, requires manual configuration
- Rejected: Security is critical, automation should include firewall

## References

- nftables wiki: https://wiki.nftables.org/
- Debian nftables documentation: https://wiki.debian.org/nftables
- ADR #0006: Automated NGINX provisioning (original firewall implementation)
- nftables quick reference: https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes
- Debian Bookworm default: https://www.debian.org/releases/bookworm/amd64/release-notes/ch-information.html
