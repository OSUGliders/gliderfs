#!/usr/bin/env bash
# Install the restic backup system from this setup/ directory, which is the
# single source of truth. Safe to re-run after any edit.
#
#   sudo ./install.sh
#
# Does NOT enable timers; do that per tree, e.g.
#   sudo systemctl enable --now restic-backup@slocum-raw.timer restic-check@slocum-raw.timer

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step() { printf '[%3ds] %s\n' "$SECONDS" "$*"; }

step "checking service account"
id gliderhelper >/dev/null

step "installing scripts, excludes and env files"
install -d -m 0755 /etc/restic /etc/restic/env

install -m 0755 "$SRC/restic-backup.sh"   /usr/local/bin/restic-backup.sh
install -m 0755 "$SRC/restic-check.sh"    /usr/local/bin/restic-check.sh
install -m 0755 "$SRC/notify-failure.sh"  /usr/local/bin/notify-failure.sh

install -m 0644 "$SRC/restic-excludes.txt"     /etc/restic/excludes.txt
install -m 0644 "$SRC/restic-excludes-raw.txt" /etc/restic/excludes-raw.txt

for env in "$SRC"/*.env; do
    [[ "$(basename "$env")" == notify.env ]] && continue
    install -m 0644 "$env" /etc/restic/env/
done

# Optional: NOTIFY_EMAIL=... for failure emails (see notify-failure@.service)
if [[ -f "$SRC/notify.env" ]]; then
    install -m 0644 "$SRC/notify.env" /etc/restic/notify.env
fi

# Scripts and env files are read fresh on every run; only unit files need a
# systemd reload, which is slow on this host, so skip it when none changed.
step "installing systemd units"
units_changed=()
for unit in restic-backup@.service restic-backup@.timer \
            restic-check@.service restic-check@.timer \
            notify-failure@.service; do
    if ! cmp -s "$SRC/$unit" "/etc/systemd/system/$unit"; then
        install -m 0644 "$SRC/$unit" /etc/systemd/system/
        units_changed+=("$unit")
    fi
done

if (( ${#units_changed[@]} )); then
    step "changed: ${units_changed[*]}"
    step "running systemctl daemon-reload (can take a while)"
    systemctl daemon-reload
else
    step "unit files unchanged; skipping daemon-reload"
fi

step "installed. Env files: $(ls /etc/restic/env)"
echo "Validate with: $SRC/validate-install.sh   (or with sudo for service-account checks)"
