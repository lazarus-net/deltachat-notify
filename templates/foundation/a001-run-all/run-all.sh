#!/bin/sh
#
# MDIST Master Deployment Script
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org
# Generated/edited with Claude
#
# This script executes all deployment stages in lexicographic order.
# Stages are executed sequentially (a001, a010, b020, ...).
# Scripts within each stage are executed sequentially (a00, a05, a10, ...).
#
# Usage:
#   ./run-all.sh [--dry-run] [--from STAGE] [--stage STAGE]
#
# Options:
#   --dry-run       Show what would be executed without running scripts
#   --from STAGE    Start execution from specified stage (e.g., --from e060-nginx)
#   --stage STAGE   Execute only the specified stage
#

set -eu
IFS='
	'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# If we're in a001-run-all subdirectory, use parent as deployment root
if [ "$(basename "$SCRIPT_DIR")" = "a001-run-all" ]; then
    DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
else
    DEPLOY_DIR="$SCRIPT_DIR"
fi
LOG_FILE="${DEPLOY_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"
DRY_RUN=0
START_FROM=""
SINGLE_STAGE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$*" | tee -a "$LOG_FILE"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$*" | tee -a "$LOG_FILE"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" | tee -a "$LOG_FILE"
}

log_stage() {
    printf "${BLUE}>>> Stage: %s${NC}\n" "$*" | tee -a "$LOG_FILE"
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --from)
            START_FROM="$2"
            shift 2
            ;;
        --stage)
            SINGLE_STAGE="$2"
            shift 2
            ;;
        -h|--help)
            head -20 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Header
echo "=========================================" | tee -a "$LOG_FILE"
echo "MDIST Deployment Script" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
log_info "Started: $(date)"
log_info "Deploy directory: $DEPLOY_DIR"
log_info "Log file: $LOG_FILE"
if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "DRY RUN MODE - No scripts will be executed"
fi
if [ -n "$START_FROM" ]; then
    log_info "Starting from stage: $START_FROM"
fi
if [ -n "$SINGLE_STAGE" ]; then
    log_info "Executing only stage: $SINGLE_STAGE"
fi
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log_warn "Not running as root. Some scripts may require root privileges."
fi

# Track execution state
STAGE_COUNT=0
SCRIPT_COUNT=0
SKIP_MODE=0

if [ -n "$START_FROM" ]; then
    SKIP_MODE=1
fi

# Execute stages in lexicographic order
for stage_dir in "${DEPLOY_DIR}"/[a-z][0-9][0-9][0-9]-*/; do
    [ -d "$stage_dir" ] || continue

    stage_name=$(basename "$stage_dir")

    # Handle --stage filter
    if [ -n "$SINGLE_STAGE" ] && [ "$stage_name" != "$SINGLE_STAGE" ]; then
        continue
    fi

    # Handle --from logic
    if [ "$SKIP_MODE" -eq 1 ]; then
        if [ "$stage_name" = "$START_FROM" ]; then
            SKIP_MODE=0
            log_info "Starting execution from stage: $stage_name"
        else
            log_info "Skipping stage: $stage_name (before --from target)"
            continue
        fi
    fi

    log_stage "$stage_name"
    STAGE_COUNT=$((STAGE_COUNT + 1))

    # Execute scripts in stage in lexicographic order
    STAGE_SCRIPT_COUNT=0
    for script in "${stage_dir}"[a-z][0-9][0-9]-*.sh; do
        [ -f "$script" ] || continue

        script_name=$(basename "$script")

        # Skip run-all.sh itself if it exists in a stage
        if [ "$script_name" = "run-all.sh" ]; then
            continue
        fi

        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        STAGE_SCRIPT_COUNT=$((STAGE_SCRIPT_COUNT + 1))

        if [ "$DRY_RUN" -eq 1 ]; then
            log_info "[DRY-RUN] Would execute: $script_name"
        else
            log_info "Executing: $script_name"

            # Run script and capture exit code (POSIX-compliant)
            # Cannot rely on $? after pipe, must capture before piping
            TEMP_OUTPUT="${DEPLOY_DIR}/.script_output.$$"
            if sh "$script" > "$TEMP_OUTPUT" 2>&1; then
                EXIT_CODE=0
            else
                EXIT_CODE=$?
            fi

            # Display and log the output
            cat "$TEMP_OUTPUT" | tee -a "$LOG_FILE"
            rm -f "$TEMP_OUTPUT"

            if [ "$EXIT_CODE" -eq 0 ]; then
                log_info "[OK] $script_name completed successfully"
            else
                log_error "[FAIL] $script_name failed with exit code $EXIT_CODE"
                log_error "Deployment aborted. Check log: $LOG_FILE"
                exit "$EXIT_CODE"
            fi
        fi
    done

    if [ "$STAGE_SCRIPT_COUNT" -eq 0 ]; then
        log_warn "No scripts found in stage: $stage_name"
    fi

    echo "" | tee -a "$LOG_FILE"
done

# Summary
echo "=========================================" | tee -a "$LOG_FILE"
echo "MDIST Deployment Summary" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
log_info "Stages processed: $STAGE_COUNT"
log_info "Scripts executed: $SCRIPT_COUNT"
log_info "Completed: $(date)"
if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "This was a DRY RUN - no changes were made"
fi
echo "=========================================" | tee -a "$LOG_FILE"

if [ "$SCRIPT_COUNT" -eq 0 ]; then
    log_warn "No scripts were executed. Check directory structure."
    exit 1
fi

log_info "Deployment completed successfully!"
exit 0
