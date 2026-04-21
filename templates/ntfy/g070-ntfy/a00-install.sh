#!/bin/sh
#
# Download and install ntfy notification server
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# ntfy: simple pub/sub HTTP push notification service
# https://github.com/binwiederhier/ntfy
#
set -eu
IFS='
	'

VERSION="${ntfy_version}"
ARCH="linux_amd64"
INSTALL_DIR="/usr/local/bin"
BINARY="${INSTALL_DIR}/ntfy"
TMP_DIR="$(mktemp -d)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then log_error "Run as root"; exit 1; fi
}

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

check_installed() {
    if [ -f "$BINARY" ]; then
        current=$("$BINARY" version 2>/dev/null | head -1 || echo "unknown")
        log_info "ntfy already installed: $current"
        if printf '%s' "$current" | grep -q "${VERSION#v}"; then
            log_info "Version matches ${VERSION} - skipping download"
            return 0
        fi
        log_info "Version mismatch - updating to ${VERSION}"
    fi
    return 1
}

download_ntfy() {
    tarball="ntfy_${VERSION#v}_${ARCH}.tar.gz"
    url="https://github.com/binwiederhier/ntfy/releases/download/${VERSION}/${tarball}"
    log_info "Downloading ntfy ${VERSION}"
    log_info "URL: $url"
    curl -fsSL -o "${TMP_DIR}/${tarball}" "$url"
    tar -xzf "${TMP_DIR}/${tarball}" -C "$TMP_DIR"
    systemctl stop ntfy 2>/dev/null || true
    find "$TMP_DIR" -name "ntfy" -type f | head -1 | xargs -I{} cp {} "$BINARY"
    chmod 0755 "$BINARY"
    log_info "ntfy installed to $BINARY"
}

setup_users_dirs() {
    log_info "Creating ntfy directories"
    mkdir -p /etc/ntfy
    mkdir -p "$(dirname "${ntfy_cache_file}")"
    mkdir -p "$(dirname "${ntfy_auth_file}")"

    id ntfy >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -d /var/lib/ntfy ntfy
    chown ntfy:ntfy "$(dirname "${ntfy_cache_file}")" "$(dirname "${ntfy_auth_file}")"
}

log_info "========================================="
log_info "ntfy Installation"
log_info "========================================="

require_root
check_installed || download_ntfy
setup_users_dirs

log_info "ntfy version: $("$BINARY" version 2>/dev/null | head -1 || echo unknown)"
log_info "ntfy installed"
