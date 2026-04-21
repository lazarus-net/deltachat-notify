#!/bin/sh
#
# Request TLS certificate for ntfy domain via acmetool
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# acmetool is installed by chatmail/relay. This script requests a cert for
# the ntfy subdomain so the nginx vhost can use it.
# Idempotent - skips if cert already exists and is valid.
#
set -eu
IFS='
	'

DOMAIN="${ntfy_domain}"
CERT_PATH="/var/lib/acme/live/${DOMAIN}/fullchain"

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then echo "[ERROR] Run as root" >&2; exit 1; fi
}

require_acmetool() {
    if ! command -v acmetool >/dev/null 2>&1; then
        echo "[ERROR] acmetool not found - deploy chatmail/relay first" >&2
        exit 1
    fi
}

log_info "========================================="
log_info "TLS Certificate for ${DOMAIN}"
log_info "========================================="

require_root
require_acmetool

if [ -f "$CERT_PATH" ]; then
    log_info "Certificate already exists: $CERT_PATH"
else
    log_info "Requesting certificate for ${DOMAIN}"
    acmetool want "${DOMAIN}"
    log_info "Certificate obtained: $CERT_PATH"
fi
