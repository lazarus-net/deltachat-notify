# Server settings for S03-DeltaChat
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# Delta Chat chatmail relay (via chatmail/relay) + ntfy webhook notifications.
# chatmail/relay manages: Postfix, Dovecot, Nginx, TLS (acmetool), OpenDKIM,
# filtermail, Iroh relay, TURN, push notifications.
# MDIST manages: server baseline + ntfy.

export SERVER_ID=my_chatmail_server

export HOST_NAME=deltachat.example.org
export HOST_IP=203.0.113.1
export ADMIN_EMAIL=vld.lazar@proton.me

# Feature flags - set to 1 to enable, 0 to disable
export ENABLE_SWAP     := 1
export ENABLE_CHATMAIL := 1
export ENABLE_NTFY     := 1
# ENABLE_NGINX not needed - chatmail/relay installs and configures nginx itself
