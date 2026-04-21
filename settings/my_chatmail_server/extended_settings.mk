#
# Extended settings for my_chatmail_server
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude

export swap_size := 1G
export server_age_identity          := /root/.config/age/mdist-identity.txt
export letsencrypt_age_identity_path := $(server_age_identity)

# Deployment
export deploy_ssh_identity := /root/.ssh/id_ed25519
export deploy_user         := root
export deploy_host         := $(HOST_IP)
export deploy_path         := /root/mdist-deploy

# chatmail/relay - local path to cloned repo on build machine
# Clone once with: git clone https://github.com/chatmail/relay $(chatmail_relay_dir)
export chatmail_relay_dir  := $(HOME)/src/chatmail-relay
export chatmail_domain     := deltachat.example.org

# ntfy webhook notification server
# TLS via acmetool (installed by chatmail/relay) - cert path format:
#   /var/lib/acme/live/DOMAIN/fullchain and privkey
export ntfy_version    := v2.11.0
export ntfy_domain     := ntfy.example.org
export ntfy_port       := 8090
export ntfy_base_url   := https://ntfy.example.org
export ntfy_cache_file := /var/cache/ntfy/cache.db
export ntfy_auth_file  := /var/lib/ntfy/auth.db
# These are used in the nginx vhost template (acmetool cert paths)
export ntfy_tls_cert   := /var/lib/acme/live/ntfy.example.org/fullchain
export ntfy_tls_key    := /var/lib/acme/live/ntfy.example.org/privkey
# Reuse nginx_hsts_max_age and nginx_client_max_body_size from ntfy nginx template
export nginx_hsts_max_age         := 63072000
export nginx_client_max_body_size := 4M
