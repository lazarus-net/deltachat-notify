#!/bin/sh
#
# Validate POSIX sh Compliance
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org
# Generated/edited with Claude
#
# Description:
#   Validates that all shell scripts in the project use POSIX sh, not bash.
#   Checks for common bash-specific features that should be avoided.
#
# Usage:
#   ./scripts/validate_posix.sh
#
# Exit codes:
#   0 - All scripts are POSIX compliant
#   1 - Found non-compliant scripts
#

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0

echo "========================================="
echo "POSIX sh Compliance Validation"
echo "========================================="
echo ""

# Check for bash shebangs
echo "Checking for bash shebangs..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -l "^#!/bin/bash" {} \; 2>/dev/null | grep .; then
    echo "ERROR: Found scripts with #!/bin/bash shebang (should be #!/bin/sh)"
    EXIT_CODE=1
else
    echo "  [OK] All scripts use #!/bin/sh"
fi
echo ""

# Check for [[ extended test syntax
echo "Checking for [[ extended test syntax..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -E "while +\[\[|if +\[\[" {} + 2>/dev/null | grep .; then
    echo "ERROR: Found scripts with [[ test syntax (use [ ] instead)"
    EXIT_CODE=1
else
    echo "  [OK] No [[ test syntax found"
fi
echo ""

# Check for echo -e usage
echo "Checking for echo -e usage..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -n "echo -e" {} + 2>/dev/null | grep .; then
    echo "ERROR: Found 'echo -e' usage (use printf instead)"
    EXIT_CODE=1
else
    echo "  [OK] No echo -e usage found"
fi
echo ""

# Check for pipefail
echo "Checking for pipefail..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -n "pipefail" {} + 2>/dev/null | grep .; then
    echo "ERROR: Found 'pipefail' usage (not POSIX, use set -eu only)"
    EXIT_CODE=1
else
    echo "  [OK] No pipefail usage found"
fi
echo ""

# Check for ANSI-C quoting in IFS
echo "Checking for ANSI-C quoting in IFS..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -n "IFS=\\\$'" {} + 2>/dev/null | grep .; then
    echo "ERROR: Found ANSI-C quoting IFS=\$'...' (use literal newline/tab)"
    EXIT_CODE=1
else
    echo "  [OK] No ANSI-C quoting found"
fi
echo ""

# Check for bash arrays
echo "Checking for bash arrays..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -nE "declare -[aA]|\\$\\{[a-zA-Z_][a-zA-Z0-9_]*\\[|\\[@\\]|\\[\\*\\]" {} + 2>/dev/null | grep .; then
    echo "ERROR: Found bash array syntax (arrays not available in POSIX sh)"
    EXIT_CODE=1
else
    echo "  [OK] No bash array syntax found"
fi
echo ""

# Check for source command
echo "Checking for source command..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -nE "^source |[[:space:]]source " {} + 2>/dev/null | grep .; then
    echo "ERROR: Found 'source' command (use . instead)"
    EXIT_CODE=1
else
    echo "  [OK] No source command found"
fi
echo ""

# Check Makefile for bash usage (not documentation)
echo "Checking Makefile for bash usage..."
if grep -nE '(SHELL.*bash|[^#]*\bbash\s+[^;]+\.sh)' "$ROOT_DIR/Makefile" 2>/dev/null | grep .; then
    echo "ERROR: Found bash execution in Makefile (should use sh)"
    EXIT_CODE=1
else
    echo "  [OK] No bash execution found in Makefile"
fi
echo ""

# Check for unicode/emoji characters in scripts
echo "Checking for unicode/emoji characters..."
if find "$ROOT_DIR/templates" -name "*.sh" -type f -exec grep -nP '[^\x00-\x7F]' {} + 2>/dev/null | grep .; then
    echo "ERROR: Found non-ASCII characters (use ASCII only)"
    EXIT_CODE=1
else
    echo "  [OK] All scripts use ASCII characters only"
fi
echo ""

# Summary
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "[OK] All scripts are POSIX sh compliant"
    echo "========================================="
else
    echo "[FAIL] POSIX compliance check FAILED"
    echo "========================================="
    echo ""
    echo "See ADR #0012 for POSIX sh guidelines:"
    echo "  docs/adr/0012-posix-sh-shell-standard.md"
fi

exit $EXIT_CODE
