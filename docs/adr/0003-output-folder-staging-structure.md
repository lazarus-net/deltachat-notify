# 0003 - Output Folder Staging Structure

Date: 2025-10-31
Status: Accepted
Deciders: vld.lazar@proton.me
Consulted: Server configuration workflow analysis
Informed: System administrators
Tags: infrastructure, deployment, automation, organization

## Summary

Implemented staged directory structure in `out/SERVER_ID/` using XNNN-COMMENT format for stages and
XNN-name.sh format for scripts. Both levels use lexicographic ordering for execution. Letter X
provides 26 categories (a=foundation, e=services, z=finalization), NNN allows 999 stages per
category, gaps allow insertions. Scripts execute sequentially: sort stages, sort scripts within
each stage, execute in order.

**Key benefit:** Simple "sort and execute" model, no dependency resolution needed.

## Quick Reference

| Item | Value |
|------|-------|
| **Stage format** | `XNNN-COMMENT/` (e.g., `a010-swap/`, `e060-nginx/`) |
| **Script format** | `XNN-name.sh` (e.g., `a00-install.sh`, `a10-config.sh`) |
| **Execution** | Lexicographic sort at both levels |
| **Numbering** | Start 001/00, increment by 10, allows 9 insertions |
| **Examples** | See `docs/adr/references/staging-structure-examples.md` |

### Stage Categories

| Letter | Category | Examples |
|--------|----------|----------|
| a | Foundation | system-init, swap, partitions |
| b | Network | interfaces, wireguard, DNS |
| c | Security | ufw, fail2ban, ssh-config |
| d | Dependencies | python, nodejs, build-tools |
| e | Services | postgresql, redis, nginx |
| f | Applications | matrix, mail-server, web-apps |
| g | Data | db-init, data-restore |
| h | Configuration | sysctl, limits, performance |
| z | Finalization | monitoring, health-check |

## Context

MDIST generates configuration scripts in `out/SERVER_ID/`. Without structure:
- Unclear execution order causes failures (e.g., service before dependencies)
- Hard to add scripts without breaking workflows
- Manual tracking of "what's been run" is error-prone

**Requirements:**
- Clear, enforceable execution order
- Consistent ordering semantics
- Human-readable names
- Sortable structure
- Extensible
- Self-documenting

## Decision

**Staged directory structure with XNNN-COMMENT/ naming:**

### Naming Convention

**Stages:** `XNNN-COMMENT/`
- X = letter (a-z) for category
- NNN = 3-digit number (001-999) for sequence
- COMMENT = kebab-case description

**Scripts:** `XNN-name.sh`
- X = letter (a-z) to prevent octal/hex interpretation
- NN = 2-digit number (00-99) for order
- name = kebab-case description

### Execution Rules

1. Stages execute in lexicographic order (a001, a010, b020, etc.)
2. Scripts within stages execute in lexicographic order (a00, a10, a20, etc.)
3. Simple model: sort and execute, no dependency resolution
4. Consistent semantics at both levels

### Numbering Scheme

- Start at 001 for stages, 00 for scripts
- Increment by 10: allows 9 insertions between numbers
- Gaps are fine: not all numbers need to be used
- Same number, different letters OK: `a010-swap/` and `b010-network/` independent

**Example:** `a001-system-init/`, `a010-swap/`, `e060-nginx/`, `z990-monitoring/`

Full examples in `docs/adr/references/staging-structure-examples.md`

## Consequences

**Positive:** Consistent semantics, simple "sort and execute" model, self-documenting names,
extensible (26 categories x 999 stages), flexible insertion (increment-by-10), automation-friendly,
human-readable, no octal/hex issues.

**Negative:** Manual categorization requires judgment, learning curve, refactoring cost when moving
scripts, numbering gaps may look unusual, no built-in parallelism.

**Risks:** Over-organization (mitigation: keep coarse-grained), category ambiguity (use best
judgment), convention enforcement (document in CLAUDE.md, add validation).

### Follow-up Work

- [ ] Update Makefile to create staged directories automatically
- [ ] Create master execution script (run all stages/scripts in sorted order)
- [ ] Add stage validation (executable check, well-formed names)
- [ ] Document stage categories in templates/README.md
- [ ] Create utility to list stages/scripts and execution order
- [ ] Add progress tracking/logging for execution runs

## Alternatives

### A: Flat directory with numeric prefixes
`001-swap.sh`, `002-network.sh`, `003-firewall.sh`
- **Pro:** Simpler, explicit order
- **Con:** No grouping, 999 script limit, no categories
- **Rejected:** No organizational structure

### B: Single-level directories, numbers only
`010-system/`, `020-network/`, `030-services/`
- **Pro:** Simple numbering
- **Con:** Limited to 999 stages total, less extensible
- **Rejected:** No category system

### C: Multi-level nested categories
`01-foundation/01-system/`, `01-foundation/02-swap/`
- **Pro:** Hierarchical organization
- **Con:** Complex paths, harder to script, execution order ambiguous
- **Rejected:** Too complex for simple sequential execution

## References

- **Full examples:** `docs/adr/references/staging-structure-examples.md`
- SysV init runlevels: `/etc/rc*.d/` naming convention
- CDIST configuration: https://www.cluenet.de/~nico/cdist/
- ADR #0002: Swap file configuration (first template using this structure)
