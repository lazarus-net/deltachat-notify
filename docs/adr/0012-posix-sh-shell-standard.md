# 0012 - POSIX sh Shell Standard

Date: 2025-11-05
Status: Accepted
Author: vld.lazar@proton.me
Implemented: 2025-11-05
Files-changed: 8 files (6 templates, Makefile, validation script)
Related-ADRs: #0003, #0010
Tags: standards, portability, shell, scripting, posix

## Summary

Converted all shell scripts from bash to POSIX sh for maximum portability. Changed shebangs
(#!/bin/bash -> #!/bin/sh), replaced bash features (set -euo pipefail -> set -eu, [[ ]] -> [ ],
echo -e -> printf, bash arrays -> string concatenation). Created validation script
`scripts/validate_posix.sh`. Changed 8 files total.

**Key change:** All scripts now run on any POSIX-compliant shell (Alpine/BusyBox/minimal containers).

## Quick Reference

| Item | Value |
|------|-------|
| **Commands** | `./scripts/validate_posix.sh`, `make deploy_run` |
| **Files** | `templates/*/a*.sh` (6 files), `Makefile:398-399` |
| **Key changes** | Shebang, IFS, test syntax, pipefail removed, arrays converted |
| **Full reference** | `docs/adr/references/posix-sh-reference.md` |

### Common Conversions

| Bash | POSIX sh |
|------|----------|
| `#!/bin/bash` | `#!/bin/sh` |
| `set -euo pipefail` | `set -eu` |
| `[[ ... ]]` | `[ ... ]` |
| `echo -e "foo\nbar"` | `printf "foo\nbar\n"` |
| `IFS=$'\n\t'` | `IFS='<newline><tab>'` (literal) |
| `{1..10}` | `i=1; while [ $i -le 10 ]; do ... i=$((i+1)); done` |
| `cmd \| tee file; code=$?` | Use temp file (see Pipeline Exit Codes below) |

### Pipeline Exit Codes (Critical Issue)

**Problem:** Pipelines return exit code of LAST command. `cmd \| tee log; echo $?` shows tee's exit (0), not cmd's.

**Solution:** Capture before piping: `cmd > /tmp/out.$$ 2>&1; CODE=$?; cat /tmp/out.$$ \| tee log`

**Why:** `set -o pipefail` is bash-only. See `templates/foundation/a001-run-all/run-all.sh:167-186`.

## Context

MDIST scripts initially used bash with features like `set -o pipefail`, `[[ ... ]]`, `echo -e`,
and `IFS=$'\n\t'`. This creates portability issues:

- Alpine Linux uses ash/busybox sh by default
- Minimal Docker images often lack bash
- Requires additional package installation
- MDIST aims for lightweight, portable deployment

**Requirements:**
- Run on any POSIX-compliant shell
- No bash dependencies
- Consistent shell usage
- Maintain readability
- Easy verification

## Decision

**Adopt POSIX sh as the standard shell for all MDIST scripts.**

All shell scripts must:
1. Use `#!/bin/sh` shebang
2. Use only POSIX-compliant syntax
3. Avoid bash-specific extensions
4. Follow documented POSIX alternatives (see reference doc)

### Files Converted

**Templates (6 files):**
- `templates/foundation/a001-run-all/run-all.sh`
- `templates/foundation/a010-swap/a00-configure_swap.sh`
- `templates/nginx/e060-nginx/a00-install_nginx.sh`
- `templates/nginx/e060-nginx/a03-deploy_secrets.sh`
- `templates/nginx/e060-nginx/a05-request_letsencrypt.sh`
- `templates/nginx/e060-nginx/a10-configure_nginx.sh`

**Makefile (2 lines):**
- `deploy_run`: `bash run-all.sh` -> `sh run-all.sh`
- `deploy_check`: `bash run-all.sh --dry-run` -> `sh run-all.sh --dry-run`

### Validation Script

Created `scripts/validate_posix.sh` to enforce compliance:
- Checks for `#!/bin/bash` shebangs
- Detects `[[ ]]` test syntax
- Finds `echo -e` usage
- Scans Makefile for bash references
- Exit code 0 = compliant, 1 = violations found

Usage: `./scripts/validate_posix.sh`

## Consequences

### Positive

- Universal portability (any POSIX system)
- No bash installation needed
- Container-friendly (Alpine, BusyBox, minimal images)
- Lighter weight and faster
- Single shell standard
- Better code discipline

### Negative

- More verbose, less convenient features, no arrays, manual pipeline error handling

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| sed/awk slower than bash built-ins | Acceptable (not performance-critical) |
| BusyBox quirks | Test on Alpine before deploy |

## Alternatives

### A: Continue using bash
- **Pro:** More features, convenient, familiar
- **Con:** Requires bash, less portable, not minimal-container friendly
- **Rejected:** Conflicts with lightweight, portable goals

### B: Bash with fallback detection
Detect bash availability and use different code paths.
- **Pro:** Best of both worlds
- **Con:** Two code paths, complex, error-prone
- **Rejected:** Adds complexity, defeats standardization

### C: Use dash explicitly (`#!/bin/dash`)
- **Pro:** Lightweight POSIX shell
- **Con:** Not universally available
- **Rejected:** `/bin/sh` more portable (often links to dash anyway)

## References

- **Full conversion table & examples:** `docs/adr/references/posix-sh-reference.md`
- POSIX specification: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
- Rich's sh tricks: https://www.etalabs.net/sh_tricks.html
- Shellcheck POSIX mode: https://github.com/koalaman/shellcheck
