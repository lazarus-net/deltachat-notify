#!/bin/sh
#
# Create all required DNS records for a chatmail deployment
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# Usage:
#   chatmail_setup_zone.sh DOMAIN IP TOKEN_FILE AGE_KEY SSH_IDENTITY
#
# Creates: MX, _mta-sts TXT, DKIM TXT, SPF TXT, DMARC TXT, _adsp TXT, 4x SRV
# Idempotent: skips records that already exist.
# DKIM key is fetched live from the server via SSH.
#
set -eu
IFS='
	'

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()   { printf "${GREEN}[CREATED]${NC} %s %s\n" "$1" "$2"; }
log_skip() { printf "${YELLOW}[EXISTS] ${NC} %s %s\n" "$1" "$2"; }
log_err()  { printf "${RED}[ERROR]  ${NC} %s %s: %s\n" "$1" "$2" "$3" >&2; }
log_info() { printf "${GREEN}[INFO]   ${NC} %s\n" "$*"; }

usage() {
    printf 'Usage: %s DOMAIN IP TOKEN_FILE AGE_KEY SSH_IDENTITY\n' "$0"
    exit 1
}

if [ $# -ne 5 ]; then usage; fi

DOMAIN="$1"
IP="$2"
TOKEN_FILE="$3"
AGE_KEY="$4"
SSH_IDENTITY="$5"

ZONE=$(printf '%s' "$DOMAIN" | sed 's/^[^.]*\.//')

for cmd in age curl jq ssh; do
    command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s not found\n' "$cmd" >&2; exit 1; }
done

printf '\n'
log_info "========================================="
log_info "Chatmail DNS Zone Setup: $DOMAIN"
log_info "========================================="

# Decrypt token
token=$(age --decrypt -i "$AGE_KEY" "$TOKEN_FILE" 2>/dev/null) \
    || { printf 'ERROR: Failed to decrypt token\n' >&2; exit 1; }
trap 'unset token' EXIT INT TERM

# Get zone ID
resp=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
    -H "Authorization: Bearer $token" -H "Content-Type: application/json")
zone_id=$(printf '%s' "$resp" | jq -r '.result[0].id')
[ -z "$zone_id" ] || [ "$zone_id" = "null" ] && { printf 'ERROR: Zone not found: %s\n' "$ZONE" >&2; exit 1; }
log_info "Zone: $ZONE (id: $zone_id)"

# Create or update a record (idempotent, updates if content changed)
cf_upsert() {
    _name="$1"; _type="$2"; _content="$3"; _payload="$4"
    _check=$(curl -sf \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$_type&name=$_name" \
        -H "Authorization: Bearer $token" -H "Content-Type: application/json")
    _count=$(printf '%s' "$_check" | jq -r '.result | length')
    if [ "$_count" = "0" ]; then
        _r=$(curl -sf -X POST \
            "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
            -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "$_payload")
        if [ "$(printf '%s' "$_r" | jq -r '.success')" = "true" ]; then
            log_ok "$_type" "$_name"
        else
            log_err "$_type" "$_name" "$(printf '%s' "$_r" | jq -r '.errors[0].message // "unknown"')"
        fi
    else
        _existing_content=$(printf '%s' "$_check" | jq -r '.result[0].content')
        if [ "$_existing_content" = "$_content" ]; then
            log_skip "$_type" "$_name"
        else
            _record_id=$(printf '%s' "$_check" | jq -r '.result[0].id')
            _r=$(curl -sf -X PUT \
                "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$_record_id" \
                -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
                -d "$_payload")
            if [ "$(printf '%s' "$_r" | jq -r '.success')" = "true" ]; then
                printf "${GREEN}[UPDATED]${NC} %s %s\n" "$_type" "$_name"
            else
                log_err "$_type" "$_name" "$(printf '%s' "$_r" | jq -r '.errors[0].message // "unknown"')"
            fi
        fi
    fi
}

printf '\n--- Required records\n'

# MX
cf_upsert "$DOMAIN" "MX" "$DOMAIN" \
    "{\"type\":\"MX\",\"name\":\"$DOMAIN\",\"content\":\"$DOMAIN\",\"priority\":10,\"ttl\":3600,\"proxied\":false}"

# _mta-sts TXT - preserve existing sts_id if record already exists
sts_id=$(date -u +%Y%m%d%H%M)
_existing_sts=$(curl -sf \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=TXT&name=_mta-sts.$DOMAIN" \
    -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
    | jq -r '.result[0].content // ""')
if [ -n "$_existing_sts" ]; then
    sts_value="$_existing_sts"
    log_skip "TXT" "_mta-sts.$DOMAIN (keeping existing: $sts_value)"
else
    sts_value="v=STSv1; id=$sts_id"
    cf_upsert "_mta-sts.$DOMAIN" "TXT" "$sts_value" \
        "{\"type\":\"TXT\",\"name\":\"_mta-sts.$DOMAIN\",\"content\":\"$sts_value\",\"ttl\":3600}"
fi

# DKIM TXT - derive from private key (same method as cmdeploy)
log_info "Fetching DKIM public key from $DOMAIN via SSH..."
dkim_pubkey=$(ssh -i "$SSH_IDENTITY" -o StrictHostKeyChecking=accept-new "root@$DOMAIN" \
    "openssl rsa -in /etc/dkimkeys/opendkim.private -pubout 2>/dev/null \
    | awk '/-/{next}{printf(\"%s\",\$0)}'") \
    || { printf 'ERROR: Could not fetch DKIM key from server\n' >&2; exit 1; }
dkim_value="v=DKIM1;k=rsa;p=${dkim_pubkey};s=email;t=s"
dkim_payload=$(jq -n --arg name "opendkim._domainkey.$DOMAIN" --arg content "$dkim_value" \
    '{"type":"TXT","name":$name,"content":$content,"ttl":3600}')
cf_upsert "opendkim._domainkey.$DOMAIN" "TXT" "$dkim_value" "$dkim_payload"

printf '\n--- Recommended records\n'

# SPF
cf_upsert "$DOMAIN" "TXT" "v=spf1 a ~all" \
    "{\"type\":\"TXT\",\"name\":\"$DOMAIN\",\"content\":\"v=spf1 a ~all\",\"ttl\":3600}"

# DMARC
cf_upsert "_dmarc.$DOMAIN" "TXT" "v=DMARC1;p=reject;adkim=s;aspf=s" \
    "{\"type\":\"TXT\",\"name\":\"_dmarc.$DOMAIN\",\"content\":\"v=DMARC1;p=reject;adkim=s;aspf=s\",\"ttl\":3600}"

# _adsp
cf_upsert "_adsp._domainkey.$DOMAIN" "TXT" "dkim=discardable" \
    "{\"type\":\"TXT\",\"name\":\"_adsp._domainkey.$DOMAIN\",\"content\":\"dkim=discardable\",\"ttl\":3600}"

# SRV records (Cloudflare stores content as "priority weight port target")
for proto_port in "submission:_tcp:587" "submissions:_tcp:465" "imap:_tcp:143" "imaps:_tcp:993"; do
    svc=$(printf '%s' "$proto_port" | cut -d: -f1)
    proto=$(printf '%s' "$proto_port" | cut -d: -f2)
    port=$(printf '%s' "$proto_port" | cut -d: -f3)
    srv_name="_${svc}.${proto}.$DOMAIN"
    cf_upsert "$srv_name" "SRV" "0 1 $port $DOMAIN" \
        "{\"type\":\"SRV\",\"name\":\"$srv_name\",\"data\":{\"priority\":0,\"weight\":1,\"port\":$port,\"target\":\"$DOMAIN\"},\"ttl\":3600}"
done

printf '\n'
log_info "========================================="
log_info "Zone setup complete"
log_info "========================================="
log_info "Run: make settings=XXXX chatmail_dns  to verify"
printf '\n'
