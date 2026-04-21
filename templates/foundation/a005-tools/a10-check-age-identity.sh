#!/bin/sh
#
# Check that Age identity file exists on the server.
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org
# Generated/edited with Claude
#
# Description:
#   This script verifies that the Age identity file exists at the configured
#   path and has correct permissions. It does NOT install or create the file.
#   Use 'make settings=SERVER_ID deploy_age_identity' to deploy the identity.
#
set -eu
IFS='
	'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$*"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$*"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*"
}

# Configuration from extended_settings.mk
AGE_IDENTITY_PATH="${server_age_identity}"

# Main execution
log_info "========================================="
log_info "Check Age Identity File"
log_info "========================================="
echo ""

log_info "Expected identity path: $AGE_IDENTITY_PATH"

if [ ! -f "$AGE_IDENTITY_PATH" ]; then
    log_error "Age identity file NOT found at: $AGE_IDENTITY_PATH"
    echo ""
    log_info "To deploy the Age identity file, run:"
    log_info "  make settings=SERVER_ID deploy_age_identity"
    echo ""
    exit 1
fi

log_info "Age identity file exists: OK"

# Check permissions
perms=$(stat -c '%a' "$AGE_IDENTITY_PATH")
if [ "$perms" != "600" ]; then
    log_warn "Age identity has permissions $perms (expected 600)"
    log_info "Fixing permissions..."
    chmod 600 "$AGE_IDENTITY_PATH"
    log_info "Permissions corrected to 600"
else
    log_info "Permissions are correct: 600"
fi

log_info "Age identity check: PASSED"
echo ""
