#!/bin/sh
#
# Install common utilities on targer machine.
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org
# Generated/edited with Claude Code
#
# Description:
#   This script install helper utilities that are required by other scripts.
#   It is idempotent,
#   meaning it can be run multiple times without causing issues if tool already installed.
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

# Ensure that running as root
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Wait for dpkg/apt locks to be released
wait_for_apt_lock() {
    local max_wait=300
    local wait_interval=5
    local elapsed=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do

        if [ $elapsed -eq 0 ]; then
            log_info "Waiting for other package managers to finish..."
        fi

        if [ $elapsed -ge $max_wait ]; then
            log_error "Timeout waiting for package lock (waited $max_wait seconds)"
            log_error "Another process is holding the package lock"
            log_error "Check: ps aux | grep -E \"(apt|dpkg|unattended)\""
            return 1
        fi

        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done

    if [ $elapsed -gt 0 ]; then
        log_info "Package lock released after $elapsed seconds"
    fi

    return 0
}

update_and_upgrade_system() {
    log_info "Updating package repository and upgrading system..."

    # Wait for any locks to be released
    wait_for_apt_lock || return 1

    log_info "Running apt-get update..."
    apt-get update -y

    log_info "Running apt-get upgrade..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

    log_info "System update and upgrade completed"
}

install_package() {
    pkg="$1"
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        log_info "Installing $pkg"

        # Wait for any locks to be released
        wait_for_apt_lock || return 1

        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    else
        log_info "Package $pkg already installed"
    fi
}

# Main execution
log_info "========================================="
log_info "Install Helper Tools Configuration Script"
log_info "========================================="
echo ""

# Check if running as root
require_root

# Update repository and upgrade system packages
update_and_upgrade_system

# Install bc
install_package bc

# Install sqlite3
install_package sqlite3

# Install age (file encryption tool)
install_package age

# Install jq (JSON processor, required for Matrix API scripts)
install_package jq


