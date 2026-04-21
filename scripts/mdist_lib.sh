#!/usr/bin/sh
set -euo pipefail
IFS=$'\n\t'

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "need $1"; exit 127; }; }

ensure_user() {
  local u="$1"
  id "$u" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$u"
}

ensure_sudo_nopass() {
  local u="$1" f="/etc/sudoers.d/99-$u-nopass"
  if ! sudo test -f "$f"; then
    echo "$u ALL=(ALL) NOPASSWD:ALL" | sudo tee "$f" >/dev/null
    sudo chmod 440 "$f"
  fi
}

ensure_file_mode() { sudo install -m "$2" /dev/null "$1" 2>/dev/null || true; sudo chmod "$2" "$1"; }

ensure_line() { local f="$1" line="$2"; sudo touch "$f"; sudo grep -qxF "$line" "$f" || echo "$line" | sudo tee -a "$f" >/dev/null; }

ensure_pkg_apt() {
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

ensure_service() {
  sudo systemctl enable --now "$1"
}

put_template() { # put_template /dest/file <tmpl-with-env>
  sudo tee "$1" >/dev/null
}

ensure_ufw_rule() { local port="$1"; sudo ufw status | grep -qE "\\b$port\\b" || sudo ufw allow "$port"; }

