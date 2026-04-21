#!/usr/local/lib/chatmaild/venv/bin/python3
#
# CGI script for creating new chatmail accounts with token-based access control.
#
# Author: vld.lazar@proton.me
# Copyright (C) 2026 vld.lazar@proton.me
# Generated/edited with Claude
#
# Replaces the default newemail.py from chatmail/relay.
# Reads valid tokens from /etc/chatmail/valid_tokens.txt (one token per line).
# Requires ?token=TOKEN in the POST query string.
#
import ipaddress
import json
import os
import secrets
import string
from urllib.parse import parse_qs, quote

from chatmaild.config import Config, read_config

CONFIG_PATH = "/usr/local/lib/chatmaild/chatmail.ini"
VALID_TOKENS_PATH = "/etc/chatmail/valid_tokens.txt"
ALPHANUMERIC = string.ascii_lowercase + string.digits
ALPHANUMERIC_PUNCT = string.ascii_letters + string.digits + string.punctuation


def load_valid_tokens():
    try:
        with open(VALID_TOKENS_PATH) as f:
            return {line.strip() for line in f if line.strip() and not line.startswith("#")}
    except FileNotFoundError:
        return set()


def get_request_token():
    qs = os.environ.get("QUERY_STRING", "")
    params = parse_qs(qs)
    values = params.get("token", [])
    return values[0] if values else ""


def wrap_ip(host):
    if host.startswith("[") and host.endswith("]"):
        return host
    try:
        ipaddress.ip_address(host)
        return f"[{host}]"
    except ValueError:
        return host


def create_newemail_dict(config: Config):
    user = "".join(secrets.choice(ALPHANUMERIC) for _ in range(config.username_max_length))
    password = "".join(
        secrets.choice(ALPHANUMERIC_PUNCT) for _ in range(config.password_min_length + 3)
    )
    return dict(email=f"{user}@{wrap_ip(config.mail_domain)}", password=password)


def print_new_account():
    token = get_request_token()
    valid_tokens = load_valid_tokens()

    if not valid_tokens or token not in valid_tokens:
        print("Status: 403 Forbidden")
        print("Content-Type: text/plain")
        print("")
        print("Invite only. Contact the server administrator to get an invite.")
        return

    config = read_config(CONFIG_PATH)
    creds = create_newemail_dict(config)
    result = dict(email=creds["email"], password=creds["password"])
    if config.tls_cert_mode == "self":
        result["dclogin_url"] = (
            f"dclogin:{quote(creds['email'], safe='@')}"
            f"?p={quote(creds['password'], safe='')}&v=1&ic=3"
        )

    print("Content-Type: application/json")
    print("")
    print(json.dumps(result))


if __name__ == "__main__":
    print_new_account()
