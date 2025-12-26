#!/usr/bin/env bash
#
# Script: remote-batch-add-sudo-user-and-pubkey-with-libs-v3.sh
# Description:
#   Connects as USER_NAME using SSH_KEY_PATH (passwordless),
#   creates/updates NEW_USER_NAME + NEW_USER_PASSWORD,
#   grants sudo (via group if possible, else /etc/sudoers.d),
#   and installs NEW_USER_PUBKEY_PATH into the new user's authorized_keys.
#
# .secrets required:
#   USER_NAME
#   SSH_KEY_PATH
#   NEW_USER_NAME
#   NEW_USER_PASSWORD
#   NEW_USER_PUBKEY_PATH
# optional:
#   HOSTDOMAIN=.local
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-secrets.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-hosts.sh"

SECRETS_FILE="$SCRIPT_DIR/.secrets"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"
HOSTDOMAIN="${HOSTDOMAIN:-}"

load_secrets "$SECRETS_FILE"
require_vars "$SECRETS_FILE" USER_NAME SSH_KEY_PATH NEW_USER_NAME NEW_USER_PASSWORD NEW_USER_PUBKEY_PATH
check_ssh_key_file "$SSH_KEY_PATH"

CURRENT_USER="$USER_NAME"
KEY_FILE="$SSH_KEY_PATH"
TARGET_USER="$NEW_USER_NAME"
TARGET_PASS="$NEW_USER_PASSWORD"
PUBKEY_FILE="$NEW_USER_PUBKEY_PATH"

[[ -f "$PUBKEY_FILE" ]] || { echo "❌ Missing NEW_USER_PUBKEY_PATH file: $PUBKEY_FILE" >&2; exit 2; }
PUBKEY_LINE="$(head -n 1 "$PUBKEY_FILE" | tr -d '\r\n')"
[[ "$PUBKEY_LINE" == ssh-* ]] || { echo "❌ NEW_USER_PUBKEY_PATH does not look like an SSH public key: $PUBKEY_FILE" >&2; exit 3; }

b64_encode_string() {
  local s="$1"
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    printf '%s' "$s" | base64 -w0
  else
    printf '%s' "$s" | base64 | tr -d '\n'
  fi
}
b64_encode_file() {
  local f="$1"
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    base64 -w0 "$f"
  else
    base64 "$f" | tr -d '\n'
  fi
}

PASS_B64="$(b64_encode_string "$TARGET_PASS")"
PUBKEY_B64="$(b64_encode_file "$PUBKEY_FILE")"

SSH_OPTS=(
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

SUMMARY_LOGFILE="$LOG_DIR/add-sudo-user-and-key-summary.log"
DETAIL_LOGFILE="$LOG_DIR/add-sudo-user-and-key-detail.log"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

while IFS= read -r SERVER; do
  FQDN="$(build_fqdn "$SERVER" "$HOSTDOMAIN")"

  echo "➡️  Adding sudo user + pubkey '$TARGET_USER' on $FQDN…"
  printf "\n===== %s =====\n\n" "$FQDN" | tee -a "$DETAIL_LOGFILE"

  if ssh "${SSH_OPTS[@]}" \
      "$CURRENT_USER@$FQDN" \
      "NEW_USER='$TARGET_USER' PASS_B64='$PASS_B64' PUBKEY_B64='$PUBKEY_B64' bash -s" \
      <<'EOF' 2>&1 | tee -a "$DETAIL_LOGFILE"
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing required command: $1"; exit 20; }; }

need_cmd sudo
need_cmd id
need_cmd chpasswd
need_cmd getent
need_cmd base64
need_cmd install
need_cmd grep
need_cmd cut
need_cmd touch
need_cmd chmod
need_cmd chown
need_cmd tee

if ! sudo -n true >/dev/null 2>&1; then
  echo "❌ sudo is not available non-interactively for the connecting user on this host (needs NOPASSWD or equivalent)"
  exit 21
fi

NEW_PASS="$(printf '%s' "${PASS_B64}" | base64 -d)"
PUBKEY_LINE="$(printf '%s' "${PUBKEY_B64}" | base64 -d | head -n 1 | tr -d '\r\n')"

# Decide which admin group to use, if present
ADMIN_GROUP=""
if getent group sudo >/dev/null 2>&1; then
  ADMIN_GROUP="sudo"
elif getent group wheel >/dev/null 2>&1; then
  ADMIN_GROUP="wheel"
fi

create_user() {
  local u="$1"

  if command -v adduser >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" "$u"
    return
  fi

  if command -v useradd >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "$u"
    return
  fi

  echo "❌ Neither adduser nor useradd exists on this host; cannot create users here."
  exit 23
}

grant_sudo() {
  local u="$1"

  # 1) Preferred: group membership
  if [[ -n "$ADMIN_GROUP" ]]; then
    if command -v usermod >/dev/null 2>&1; then
      sudo usermod -aG "$ADMIN_GROUP" "$u"
      echo "🛡️  Granted sudo via group '$ADMIN_GROUP' using usermod"
      return
    fi

    # Debian adduser can add existing users to groups:
    #   adduser <user> <group>
    if command -v adduser >/dev/null 2>&1; then
      sudo adduser "$u" "$ADMIN_GROUP" >/dev/null
      echo "🛡️  Granted sudo via group '$ADMIN_GROUP' using adduser"
      return
    fi
  fi

  # 2) Fallback: sudoers drop-in file
  # This works even on minimal installs that lack usermod/adduser group ops.
  local sudoers_file="/etc/sudoers.d/${u}"
  echo "🛡️  Falling back to sudoers file: $sudoers_file"
  printf '%s\n' "${u} ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudoers_file" >/dev/null
  sudo chmod 440 "$sudoers_file"

  # Validate if visudo exists (nice-to-have)
  if command -v visudo >/dev/null 2>&1; then
    if sudo visudo -cf "$sudoers_file" >/dev/null 2>&1; then
      echo "✅ sudoers file validated by visudo"
    else
      echo "❌ visudo validation failed for $sudoers_file"
      exit 24
    fi
  else
    echo "ℹ️  visudo not present; wrote sudoers file without validation"
  fi
}

if id "$NEW_USER" >/dev/null 2>&1; then
  echo "ℹ️  User exists: $NEW_USER"
else
  echo "🧑‍💻 Creating user: $NEW_USER"
  create_user "$NEW_USER"
fi

echo "🔐 Setting password for: $NEW_USER"
printf '%s:%s\n' "$NEW_USER" "$NEW_PASS" | sudo chpasswd

grant_sudo "$NEW_USER"

HOME_DIR="$(getent passwd "$NEW_USER" | cut -d: -f6)"
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

echo "🔑 Ensuring authorized_keys exists for: $NEW_USER ($AUTH_KEYS)"
sudo install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$SSH_DIR"
sudo touch "$AUTH_KEYS"
sudo chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
sudo chmod 600 "$AUTH_KEYS"

if sudo grep -Fqx "$PUBKEY_LINE" "$AUTH_KEYS" >/dev/null 2>&1; then
  echo "ℹ️  Public key already present in authorized_keys"
else
  echo "➕ Adding public key to authorized_keys"
  printf '%s\n' "$PUBKEY_LINE" | sudo tee -a "$AUTH_KEYS" >/dev/null
fi

echo "✅ Verified groups for $NEW_USER: $(id -nG "$NEW_USER" 2>/dev/null | tr ' ' ',' || echo '(unable to read groups)')"
echo "✅ Done on $(hostname -f 2>/dev/null || hostname)"
EOF
  then
    echo "$(date +'%F %T')  [OK]   Added/updated sudo user + pubkey '$TARGET_USER' on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Sudo user/pubkey add failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < <(iter_hosts "$HOSTFILE")

echo
echo "📊 Add Sudo User + Pubkey Summary"
echo "================================="
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do echo "  - $host"; done
echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do echo "  - $host"; done
echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
echo
echo "🔎 Manual verify:"
echo "    ssh -vvv -i \"$KEY_FILE\" -o IdentitiesOnly=yes \"$TARGET_USER@<host>\""
