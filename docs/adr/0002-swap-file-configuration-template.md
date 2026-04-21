# 0002 — Swap File Configuration Template
Date: 2025-10-31
Status: Accepted
Deciders: vld.lazar@proton.me
Consulted: System requirements analysis
Informed: Server administrators
Tags: infrastructure, swap, templates, configuration

## Context

The chatmail server (my_chatmail_server) and potentially other servers in the MDIST infrastructure
require swap space configuration. Swap is essential for:

1. **Memory pressure handling** - Prevents OOM (Out of Memory) kills when RAM is exhausted
2. **Hibernation support** - Required for system suspend-to-disk (if needed)
3. **Memory overcommitment** - Allows running more services than physical RAM would normally support
4. **Stability** - Linux kernel expects swap space for optimal memory management

Currently, swap configuration is manual and error-prone. We need an automated, idempotent solution
that integrates with MDIST's template-based configuration approach.

Requirements:
- Idempotent execution (safe to run multiple times)
- Configurable swap size per server
- Automatic persistence across reboots
- Validation of existing configuration
- Safe recreation when size changes

## Decision

Implement a bash script template in `templates/swap/configure_swap.sh` that:

1. Uses `fallocate` for efficient swap file creation (faster than dd)
2. Implements comprehensive idempotency checks:
   - File existence
   - Active swap status
   - Size verification
   - fstab persistence
3. Accepts `swap_size` parameter from `extended_settings.mk`
4. Uses standard `/swapfile` location (conventional path)
5. Sets secure permissions (0600, root-only access)
6. Provides color-coded logging for operational visibility
7. Automatically fixes misconfigurations (recreates swap if size mismatch)

The template follows MDIST conventions:
- Uses variable substitution via `template_subst.sh`
- Generates output to `out/SERVER_ID/swap/`
- Self-documented with inline comments
- Error handling with `set -euo pipefail`

## Consequences

### Positive
- **Consistency**: All servers get identical swap configuration logic
- **Idempotent**: Safe to run in automation/cron without side effects
- **Self-healing**: Automatically fixes misconfigured swap
- **Auditable**: Clear logging shows what actions were taken
- **Maintainable**: Single template for all servers, changes propagate automatically
- **Flexible**: Size configurable per server via settings files
- **Secure**: Proper file permissions prevent unauthorized access

### Negative
- **Dependency**: Requires `fallocate`, `bc`, and standard Linux utilities
- **Root required**: Must run with elevated privileges
- **No encryption**: Standard swap is unencrypted (sensitive data may leak to disk)
- **Fixed location**: Uses `/swapfile` hardcoded (minimal impact, standard convention)

### Risks/Trade-offs
- **Swap thrashing**: If swap_size is too small, system may thrash; if too large, wastes disk space
- **SSD wear**: Swap on SSD increases write cycles (mitigated by modern SSD longevity)
- **Unencrypted data**: Sensitive data in RAM may be written to swap (accept for now,
  encrypted swap can be added later if needed)

### Follow-up work
- Consider adding swappiness tuning (`/proc/sys/vm/swappiness`)
- Evaluate encrypted swap for servers handling sensitive data
- Add Makefile target for automated deployment
- Create monitoring/alerting for swap usage
- Document recommended swap sizes per server type

## Alternatives

### Option A: Use cloud-init/user-data scripts
- Pro: Native cloud integration
- Con: Not applicable to bare metal servers, vendor lock-in

### Option B: Use Ansible/Puppet/Chef
- Pro: Mature configuration management
- Con: Adds dependency, complexity; MDIST aims to be lightweight

### Option C: Manual swap configuration
- Pro: Simple, no automation needed
- Con: Error-prone, not repeatable, no validation, documentation drift

### Option D: Use dd instead of fallocate
- Pro: More compatible with older systems
- Con: Significantly slower, unnecessary overhead

### Option E: systemd swap units
- Pro: Native systemd integration
- Con: Requires manual unit file creation, less portable, more complex for simple use case

## References

- Linux kernel swap documentation: https://www.kernel.org/doc/html/latest/admin-guide/mm/concepts.html
- Ubuntu swap FAQ: https://help.ubuntu.com/community/SwapFaq
- fallocate man page: `man 1 fallocate`
- fstab format: `man 5 fstab`
- MDIST template_subst.sh: `/scripts/template_subst.sh`
- Server settings: `/settings/my_chatmail_server/extended_settings.mk`
