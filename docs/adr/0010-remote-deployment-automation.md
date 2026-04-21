# 0010 - Remote Deployment Automation

Date: 2025-11-03
Status: Accepted
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: System administrators, automation contributors
Informed: Server operators, deployment teams
Tags: deployment, automation, ssh, rsync, orchestration

## Summary

Implemented hybrid deployment approach combining generated master execution script (`run-all.sh`)
with Makefile targets. Script executes stages in lexicographic order, supports --dry-run, --from
STAGE, --stage STAGE modes, logs to timestamped files. Makefile provides `deploy_copy` (rsync),
`deploy_run` (SSH execute), `deploy_check` (dry-run), and `deploy` (copy+run). Settings in
`extended_settings.mk` define SSH identity, user, host, path.

## Quick Reference

| Item | Value |
|------|-------|
| **Commands** | `make deploy_copy`, `deploy_run`, `deploy_check`, `deploy` |
| **Master script** | `templates/foundation/a001-run-all/run-all.sh` |
| **Settings** | `deploy_ssh_identity`, `deploy_user`, `deploy_host`, `deploy_path` |
| **Workflows** | See `docs/adr/references/deployment-workflows.md` |

## Context

MDIST generates scripts organized by stages (ADR #0003) and features (ADR #0004). Without
automation: manual rsync/scp is error-prone, no standardized execution order, difficult progress
tracking, scattered SSH credentials, no dry-run capability, can't resume from failures.

**Requirements:** Automated file transfer, SSH key-based auth, correct execution order, progress
logging, dry-run mode, idempotent execution, resume capability, work with ADR #0003 structure.

## Decision

**Hybrid deployment approach** combining generated master execution script with Makefile targets.

### Master Execution Script (run-all.sh)

Template at `templates/foundation/a001-run-all/run-all.sh`:
- Executes all stages in lexicographic order
- Executes scripts within stages in lexicographic order
- Logs to timestamped deployment logs
- Supports --dry-run (preview without executing)
- Supports --from STAGE (resume from specific stage)
- Supports --stage STAGE (execute only one stage)
- Exits on first failure
- Skips run-all.sh itself if found in stage directory
- Auto-detects parent directory as deployment root

### Makefile Deployment Targets

```makefile
deploy_copy::   # Copy scripts to remote via rsync
deploy_run::    # Execute run-all.sh on remote via SSH
deploy_check::  # Execute run-all.sh --dry-run on remote
deploy::        # Full deployment: copy + run
```

### Deployment Settings

In `extended_settings.mk`:
```makefile
export deploy_ssh_identity := /path/to/ssh/key
export deploy_user := root
export deploy_host := $(HOST_IP)
export deploy_path := /root/mdist-deploy
```

### Execution Flow

1. Local generation: `make settings=SERVER_ID generate_all_scripts`
2. Copy to remote: `make settings=SERVER_ID deploy_copy` (rsync over SSH)
3. Execute on remote: `make settings=SERVER_ID deploy_run` (run-all.sh via SSH)
4. Or combined: `make settings=SERVER_ID deploy` (copy + run)

Full examples: `docs/adr/references/deployment-workflows.md`

## Consequences

**Positive:** Full automation (one command), secure (SSH keys), idempotent (re-runnable), resilient
(runs on remote, survives network interruptions), debuggable (inspect scripts before running),
flexible (dry-run/resume/single-stage modes), clear logging (timestamped), ADR compliant (follows
staging/features), hybrid control (Makefile or manual), template-based (run-all.sh generated),
single copy (one run-all.sh in a001-run-all/), smart path detection (auto parent directory).

**Negative:** SSH dependency (requires key setup), rsync dependency (must be installed), network
requirement (initial copy needs connectivity), additional script (run-all.sh to maintain).

**Risks:** SSH key management (distribute securely), first-run complexity (server must be SSH
accessible), parallel execution (sequential slower but safer), subdirectory execution (call with
path: `./a001-run-all/run-all.sh`).

### Follow-up Work

- [ ] Document SSH key generation and distribution process
- [ ] Add example for multi-server deployments
- [ ] Consider parallel execution mode for independent stages
- [ ] Add post-deployment verification/health checks
- [ ] Create utility to show deployment status from logs
- [ ] Consider rollback capability

## Alternatives

### A: Execute remotely via SSH from Makefile
Loop through stages and SSH for each script.
- **Pro:** Simpler, no run-all.sh needed
- **Con:** Network-dependent, can't resume, complex error handling
- **Rejected:** Not resilient to network issues

### B: Self-contained tarball
`tar czf deploy.tar.gz scripts/ && scp && ssh extract`
- **Pro:** Single artifact, offline-friendly
- **Con:** Manual extraction, no Makefile integration
- **Rejected:** Doesn't integrate with workflow

### C: Ansible/Puppet deployment
- **Pro:** Industry standard, rich features
- **Con:** Heavy dependency, overcomplicated for simple script execution
- **Rejected:** Too heavy for this use case

## References

- **Workflows:** `docs/adr/references/deployment-workflows.md`
- ADR #0003: Output folder staging structure (defines execution order)
- ADR #0004: Feature-based conditional script generation (defines template organization)
- rsync manual: https://linux.die.net/man/1/rsync
- SSH key authentication: https://www.ssh.com/academy/ssh/public-key-authentication
