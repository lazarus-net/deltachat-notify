#!/bin/sh
#
# Enable and start ntfy service
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
set -eu
IFS='
	'

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then echo "[ERROR] Run as root" >&2; exit 1; fi
}

log_info "========================================="
log_info "ntfy Service Start"
log_info "========================================="

require_root

systemctl enable ntfy
systemctl restart ntfy

if systemctl is-active --quiet ntfy; then
    log_info "ntfy running: OK"
    log_info "ntfy endpoint: ${ntfy_base_url}"
else
    echo "[ERROR] ntfy failed to start" >&2
    journalctl -u ntfy -n 20 --no-pager >&2
    exit 1
fi
