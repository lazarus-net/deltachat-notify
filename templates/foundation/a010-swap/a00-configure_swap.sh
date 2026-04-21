#!/bin/sh
#
# Configure Swap File
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org
# Generated/edited with Claude Code
#
# Description:
#   This script configures a swap file on the server. It is idempotent,
#   meaning it can be run multiple times without causing issues if swap
#   is already properly configured.
#
# Parameters (substituted from extended_settings.mk):
#   swap_size - Size of swap file (e.g., 1G, 2G, 512M)
#
# Usage:
#   ./a00-configure_swap.sh [--force]
#
# Options:
#   --force    Force recreation of swap file even if current size is acceptable
#

set -eu
IFS='
	'

# Configuration
SWAP_FILE="/swapfile"
SWAP_SIZE="${swap_size}"
FORCE_RECREATE=0

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --force)
            FORCE_RECREATE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            exit 1
            ;;
    esac
done

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

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Convert size string to bytes for comparison
size_to_bytes() {
    local size=$1
    local number
    local unit

    number=$(echo "$size" | sed 's/[^0-9.]//g')
    unit=$(echo "$size" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')

    case "$unit" in
        K|KB) echo "$number * 1024" | bc | cut -d. -f1 ;;
        M|MB) echo "$number * 1024 * 1024" | bc | cut -d. -f1 ;;
        G|GB) echo "$number * 1024 * 1024 * 1024" | bc | cut -d. -f1 ;;
        *) echo "$number" ;;
    esac
}

# Check current swap status
check_swap_status() {
    log_info "Checking current swap status..."

    # Check if swap file exists
    if [ ! -f "$SWAP_FILE" ]; then
        log_info "Swap file $SWAP_FILE does not exist"
        return 1
    fi

    # Check if swap file is active
    if ! swapon --show | grep -q "$SWAP_FILE"; then
        log_warn "Swap file exists but is not active"
        return 2
    fi

    # Check swap file size
    local current_size
    current_size=$(stat -c%s "$SWAP_FILE" 2>/dev/null || echo "0")
    local desired_size
    desired_size=$(size_to_bytes "$SWAP_SIZE")

    if [ "$current_size" -lt "$desired_size" ]; then
        log_warn "Swap file too small: current=$current_size bytes, desired=$desired_size bytes"
        return 3
    elif [ "$current_size" -gt "$desired_size" ]; then
        if [ "$FORCE_RECREATE" -eq 1 ]; then
            log_info "Swap file larger than desired, but --force specified. Will recreate."
            return 3
        else
            log_info "Swap file is larger than requested: current=$current_size bytes, desired=$desired_size bytes"
            log_info "Keeping existing swap file (safe mode). Use --force to recreate with exact size."
            # Continue without error - size is acceptable
        fi
    fi

    # Check fstab entry
    if ! grep -q "^$SWAP_FILE" /etc/fstab; then
        log_warn "Swap file not configured in /etc/fstab"
        return 4
    fi

    log_info "Swap is properly configured and active"
    return 0
}

# Remove existing swap file
remove_swap() {
    log_info "Removing existing swap configuration..."

    # Turn off swap if active
    if swapon --show | grep -q "$SWAP_FILE"; then
        log_info "Deactivating swap file..."
        swapoff "$SWAP_FILE"
    fi

    # Remove swap file
    if [ -f "$SWAP_FILE" ]; then
        log_info "Removing swap file $SWAP_FILE..."
        rm -f "$SWAP_FILE"
    fi

    # Remove fstab entry
    if grep -q "^$SWAP_FILE" /etc/fstab; then
        log_info "Removing swap entry from /etc/fstab..."
        sed -i "\|^$SWAP_FILE|d" /etc/fstab
    fi
}

# Create and configure swap file
create_swap() {
    log_info "Creating swap file: $SWAP_FILE with size: $SWAP_SIZE..."

    # Create swap file
    log_info "Allocating swap file..."
    fallocate -l "$SWAP_SIZE" "$SWAP_FILE"

    # Set proper permissions
    log_info "Setting permissions (0600)..."
    chmod 600 "$SWAP_FILE"

    # Set up swap space
    log_info "Setting up swap space..."
    mkswap "$SWAP_FILE"

    # Enable swap
    log_info "Enabling swap..."
    swapon "$SWAP_FILE"

    # Add to fstab if not present
    if ! grep -q "^$SWAP_FILE" /etc/fstab; then
        log_info "Adding swap to /etc/fstab..."
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi

    log_info "Swap configuration completed successfully"
}

# Verify swap is working
verify_swap() {
    log_info "Verifying swap configuration..."

    if swapon --show | grep -q "$SWAP_FILE"; then
        log_info "Swap is active:"
        swapon --show | grep "$SWAP_FILE" || true
        echo ""
        log_info "Total swap summary:"
        free -h | grep -i swap
        return 0
    else
        log_error "Swap verification failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "========================================="
    log_info "Swap Configuration Script"
    log_info "========================================="
    log_info "Target swap file: $SWAP_FILE"
    log_info "Target swap size: $SWAP_SIZE"
    if [ "$FORCE_RECREATE" -eq 1 ]; then
        log_warn "Force mode: ENABLED (will recreate swap regardless of size)"
    fi
    log_info "========================================="
    echo ""

    # Check if running as root
    check_root

    # Check required commands
    for cmd in fallocate mkswap swapon swapoff bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done

    # Check current status
    check_swap_status || status=$?

    if [ "${status:-0}" -eq 0 ]; then
        log_info "Swap is already properly configured. Nothing to do."
        verify_swap
        exit 0
    fi

    # Handle different status codes
    case $status in
        1)
            # Swap file doesn't exist - create it
            create_swap
            ;;
        2|3|4)
            # Swap exists but has issues - recreate
            log_warn "Swap configuration needs to be fixed. Recreating..."
            remove_swap
            create_swap
            ;;
    esac

    # Verify final state
    echo ""
    verify_swap
}

# Run main function
main "$@"
