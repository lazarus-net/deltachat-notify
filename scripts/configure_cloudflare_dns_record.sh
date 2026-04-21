#!/bin/sh
#
# Create or update a Cloudflare DNS record (A or CNAME)
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# Description:
#   Creates or updates a DNS A or CNAME record in Cloudflare.
#   Idempotent: creates if missing, updates if content changed, skips if correct.
#   Records are created as DNS-only (not proxied).
#
# Usage:
#   ./configure_cloudflare_dns_record.sh ZONE_DOMAIN RECORD_NAME RECORD_CONTENT TOKEN_FILE AGE_KEY [RECORD_TYPE]
#
# Arguments:
#   ZONE_DOMAIN    - Root zone domain (e.g. example.org)
#   RECORD_NAME    - Full record name (e.g. matrix-rtc.example.org)
#   RECORD_CONTENT - Target value: IPv4 for A, target domain for CNAME
#   TOKEN_FILE     - Path to Age-encrypted Cloudflare token (.age file, plain format)
#   AGE_KEY        - Path to Age identity file for decryption
#   RECORD_TYPE    - Optional: A (default) or CNAME
#
set -eu
IFS='
	'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_step()  { printf "${BLUE}[STEP]${NC} %s\n" "$*"; }

usage() {
    printf 'Usage: %s ZONE_DOMAIN RECORD_NAME RECORD_CONTENT TOKEN_FILE AGE_KEY [RECORD_TYPE]\n' "$0"
    printf '\n'
    printf 'Examples:\n'
    printf '  %s example.org host.example.org 203.0.113.1 token.age key.txt\n' "$0"
    printf '  %s example.org mta-sts.example.org example.org. token.age key.txt CNAME\n' "$0"
    exit 1
}

check_dependencies() {
    for cmd in age curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
}

decrypt_token() {
    token_file="$1"
    age_key="$2"
    if [ ! -f "$token_file" ]; then
        log_error "Token file not found: $token_file"
        exit 1
    fi
    if [ ! -f "$age_key" ]; then
        log_error "Age key not found: $age_key"
        exit 1
    fi
    log_step "Decrypting Cloudflare token" >&2
    token=$(age --decrypt -i "$age_key" "$token_file" 2>/dev/null)
    if [ -z "$token" ]; then
        log_error "Failed to decrypt token"
        exit 1
    fi
    printf "%s" "$token"
}

get_zone_id() {
    zone_domain="$1"
    cf_token="$2"
    log_step "Getting zone ID for: $zone_domain" >&2
    response=$(curl -sf -X GET \
        "https://api.cloudflare.com/client/v4/zones?name=${zone_domain}" \
        -H "Authorization: Bearer $cf_token" \
        -H "Content-Type: application/json")
    success=$(printf "%s" "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        log_error "Failed to get zone ID"
        printf "%s" "$response" | jq -r '.errors[]' >&2
        exit 1
    fi
    zone_id=$(printf "%s" "$response" | jq -r '.result[0].id')
    if [ -z "$zone_id" ] || [ "$zone_id" = "null" ]; then
        log_error "Zone not found: $zone_domain"
        exit 1
    fi
    log_info "Zone ID: $zone_id" >&2
    printf "%s" "$zone_id"
}

get_existing_record() {
    zone_id="$1"
    record_name="$2"
    record_type="$3"
    cf_token="$4"
    log_step "Checking existing $record_type record for: $record_name" >&2
    response=$(curl -sf -X GET \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${record_type}&name=${record_name}" \
        -H "Authorization: Bearer $cf_token" \
        -H "Content-Type: application/json")
    success=$(printf "%s" "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        log_error "Failed to query DNS records"
        printf "%s" "$response" | jq -r '.errors[]' >&2
        exit 1
    fi
    count=$(printf "%s" "$response" | jq -r '.result | length')
    if [ "$count" = "0" ]; then
        log_info "No existing $record_type record found for $record_name" >&2
        printf ""
    else
        record_id=$(printf "%s" "$response" | jq -r '.result[0].id')
        existing_content=$(printf "%s" "$response" | jq -r '.result[0].content')
        log_info "Found existing $record_type record: $record_name -> $existing_content (id: $record_id)" >&2
        printf "%s|%s" "$record_id" "$existing_content"
    fi
}

create_record() {
    zone_id="$1"
    record_name="$2"
    record_content="$3"
    record_type="$4"
    cf_token="$5"
    log_step "Creating DNS $record_type record: $record_name -> $record_content"
    payload=$(printf '{"type":"%s","name":"%s","content":"%s","ttl":300,"proxied":false}' \
        "$record_type" "$record_name" "$record_content")
    response=$(curl -sf -X POST \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer $cf_token" \
        -H "Content-Type: application/json" \
        -d "$payload")
    success=$(printf "%s" "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        log_error "Failed to create DNS record"
        printf "%s" "$response" | jq -r '.errors[]' >&2
        exit 1
    fi
    new_id=$(printf "%s" "$response" | jq -r '.result.id')
    log_info "DNS $record_type record created (id: $new_id)"
}

update_record() {
    zone_id="$1"
    record_id="$2"
    record_name="$3"
    record_content="$4"
    record_type="$5"
    cf_token="$6"
    log_step "Updating DNS $record_type record: $record_name -> $record_content"
    payload=$(printf '{"type":"%s","name":"%s","content":"%s","ttl":300,"proxied":false}' \
        "$record_type" "$record_name" "$record_content")
    response=$(curl -sf -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "Authorization: Bearer $cf_token" \
        -H "Content-Type: application/json" \
        -d "$payload")
    success=$(printf "%s" "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        log_error "Failed to update DNS record"
        printf "%s" "$response" | jq -r '.errors[]' >&2
        exit 1
    fi
    log_info "DNS $record_type record updated"
}

verify_record() {
    record_name="$1"
    record_content="$2"
    record_type="$3"
    log_step "Verifying DNS record (may take time to propagate)"
    if [ "$record_type" = "A" ]; then
        resolved=$(host "$record_name" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}' || true)
        if [ "$resolved" = "$record_content" ]; then
            log_info "DNS resolved: $record_name -> $resolved: OK"
        else
            log_warn "DNS not yet propagated (resolved: ${resolved:-none}, expected: $record_content)"
            log_warn "This is normal - DNS propagation can take 1-5 minutes"
        fi
    else
        log_info "CNAME record created - propagation check skipped"
    fi
}

main() {
    if [ $# -lt 5 ] || [ $# -gt 6 ]; then
        usage
    fi

    ZONE_DOMAIN="$1"
    RECORD_NAME="$2"
    RECORD_CONTENT="$3"
    TOKEN_FILE="$4"
    AGE_KEY="$5"
    RECORD_TYPE="${6:-A}"

    log_info "========================================="
    log_info "Cloudflare DNS $RECORD_TYPE Record Configuration"
    log_info "========================================="
    log_info "Zone:    $ZONE_DOMAIN"
    log_info "Record:  $RECORD_NAME"
    log_info "Content: $RECORD_CONTENT"
    log_info "Type:    $RECORD_TYPE"
    printf "\n"

    check_dependencies

    CF_TOKEN=$(decrypt_token "$TOKEN_FILE" "$AGE_KEY")
    trap 'unset CF_TOKEN' EXIT INT TERM

    ZONE_ID=$(get_zone_id "$ZONE_DOMAIN" "$CF_TOKEN")
    EXISTING=$(get_existing_record "$ZONE_ID" "$RECORD_NAME" "$RECORD_TYPE" "$CF_TOKEN")

    if [ -z "$EXISTING" ]; then
        create_record "$ZONE_ID" "$RECORD_NAME" "$RECORD_CONTENT" "$RECORD_TYPE" "$CF_TOKEN"
    else
        EXISTING_ID=$(printf "%s" "$EXISTING" | cut -d'|' -f1)
        EXISTING_CONTENT=$(printf "%s" "$EXISTING" | cut -d'|' -f2)
        if [ "$EXISTING_CONTENT" = "$RECORD_CONTENT" ]; then
            log_info "DNS $RECORD_TYPE record already correct: $RECORD_NAME -> $RECORD_CONTENT"
        else
            update_record "$ZONE_ID" "$EXISTING_ID" "$RECORD_NAME" "$RECORD_CONTENT" "$RECORD_TYPE" "$CF_TOKEN"
        fi
    fi

    verify_record "$RECORD_NAME" "$RECORD_CONTENT" "$RECORD_TYPE"

    printf "\n"
    log_info "========================================="
    log_info "DNS configuration complete"
    log_info "========================================="
}

main "$@"
