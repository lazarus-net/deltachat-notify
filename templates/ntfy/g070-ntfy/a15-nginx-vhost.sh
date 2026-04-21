#!/bin/sh
#
# Deploy NGINX vhost for ntfy (ntfy.example.org)
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# Proxies https://ntfy.example.org -> http://localhost:${ntfy_port}
# Requires TLS cert from certbot (letsencrypt_additional_domains includes ntfy domain).
# WebSocket support enabled (ntfy uses SSE/WebSocket for real-time delivery).
#
set -eu
IFS='
	'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_TEMPLATE="${SCRIPT_DIR}/conf/ntfy-nginx.conf"
SITE_NAME="ntfy"
CONFIG_PATH="/etc/nginx/sites-available/${SITE_NAME}.conf"
ENABLED_PATH="/etc/nginx/sites-enabled/${SITE_NAME}.conf"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then log_error "Run as root"; exit 1; fi
}

require_cert() {
    cert="${ntfy_tls_cert}"
    if [ ! -f "$cert" ]; then
        log_error "TLS cert not found: $cert"
        log_error "Run: acmetool want ${ntfy_domain}"
        exit 1
    fi
}

deploy_vhost() {
    cp "$CONF_TEMPLATE" "$CONFIG_PATH"
    chmod 0644 "$CONFIG_PATH"
    ln -sf "$CONFIG_PATH" "$ENABLED_PATH"
    log_info "ntfy vhost deployed: $CONFIG_PATH"
}

log_info "========================================="
log_info "ntfy NGINX Vhost Configuration"
log_info "========================================="

require_root
require_cert
deploy_vhost

nginx -t
systemctl reload nginx

log_info "NGINX reloaded with ntfy vhost"
