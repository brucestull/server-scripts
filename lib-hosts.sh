#!/usr/bin/env bash
# Script: lib-hosts.sh
set -euo pipefail

trim() {
  local s="${1:-}"
  s="$(sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$s")"
  printf '%s' "$s"
}

is_ipv4() {
  local s="$1"
  [[ "$s" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

build_fqdn() {
  # Usage: build_fqdn "HOST" ".local"
  # Rules:
  #  - "HOST@domain" -> "HOST.domain"
  #  - If IPv4, return as-is
  #  - If contains a dot, treat as FQDN and return as-is
  #  - Else, append HOSTDOMAIN (if non-empty), otherwise return bare
  local raw="$1"
  local hostdomain="${2:-}"

  if [[ "$raw" == *@* ]]; then
    local host_part="${raw%@*}"
    local dom_part="${raw#*@}"
    echo "${host_part}.${dom_part}"
    return
  fi

  if is_ipv4 "$raw"; then
    echo "$raw"
    return
  fi

  if [[ "$raw" == *.* ]]; then
    echo "$raw"
    return
  fi

  if [[ -n "$hostdomain" ]]; then
    echo "${raw}${hostdomain}"
  else
    echo "$raw"
  fi
}

iter_hosts() {
  # Echo cleaned hosts, one per line, skipping blanks/comments.
  local hostfile="$1"
  [[ -f "$hostfile" ]] || { echo "❌ Missing host file: $hostfile" >&2; return 1; }

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    printf '%s\n' "$line"
  done < "$hostfile"
}
