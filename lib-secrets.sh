#!/usr/bin/env bash
# Script: lib-secrets.sh
set -euo pipefail

load_secrets() {
  local secrets_file="$1"
  [[ -f "$secrets_file" ]] || { echo "❌ Missing secrets file: $secrets_file"; return 1; }

  # shellcheck disable=SC1090
  set -a
  source "$secrets_file"
  set +a
}

require_vars() {
  local secrets_file="$1"; shift
  local v
  for v in "$@"; do
    if [[ -z "${!v:-}" ]]; then
      echo "❌ $v is required in $secrets_file"
      return 1
    fi
  done
}

check_ssh_key_file() {
  local key_file="$1"
  [[ -f "$key_file" ]] || { echo "❌ Missing SSH key at $key_file"; return 1; }

  # OpenSSH is picky; keep it strict and predictable.
  if command -v stat >/dev/null 2>&1; then
    local key_perm
    key_perm="$(stat -c '%a' "$key_file" 2>/dev/null || echo 600)"
    case "$key_perm" in
      600|400) : ;;
      *)
        echo "❌ SSH key permissions too open ($key_perm). Run: chmod 600 '$key_file'"
        return 1
        ;;
    esac
  fi
}
