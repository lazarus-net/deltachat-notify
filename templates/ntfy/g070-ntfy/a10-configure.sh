#!/bin/sh
#
# Configure ntfy server
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
set -eu
IFS='
	'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="${SCRIPT_DIR}/conf"

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then echo "[ERROR] Run as root" >&2; exit 1; fi
}

log_info "========================================="
log_info "ntfy Configuration"
log_info "========================================="

require_root

cp "${CONF_DIR}/server.yml" /etc/ntfy/server.yml
chmod 0640 /etc/ntfy/server.yml
chown root:ntfy /etc/ntfy/server.yml

cp "${CONF_DIR}/ntfy.service" /etc/systemd/system/ntfy.service
systemctl daemon-reload

log_info "ntfy configured"
