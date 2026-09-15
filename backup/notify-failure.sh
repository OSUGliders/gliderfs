#!/usr/bin/env bash
# Called by notify-failure@.service when a restic unit fails (OnFailure=).
# Writes a flag file with the recent journal into $STATUS_DIR, and sends an
# email to every address in NOTIFY_EMAIL (space/comma separated) if a `mail`
# command is available. NOTIFY_EMAIL comes from /etc/restic/notify.env,
# installed from setup/notify.env by install.sh.
#
# The backup/check scripts remove their flag file after a successful run,
# so `ls $STATUS_DIR` is a quick "is anything currently broken?" view.
#
# Usage: notify-failure.sh <failed-unit-name>

set -uo pipefail

UNIT="${1:?usage: notify-failure.sh <unit>}"
STATUS_DIR="${STATUS_DIR:-/storage/t3/dept/ceoas/grg/backup/STATUS}"
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"
# Runs as root, so without this mail would come from root@<host>.
NOTIFY_FROM="${NOTIFY_FROM:-gliderhelper@$(hostname -f)}"
FLAG="${STATUS_DIR}/${UNIT}.failed"

REPORT="$(
    echo "Unit ${UNIT} failed on $(hostname) at $(date -Is)"
    echo
    systemctl status --no-pager --lines=0 "$UNIT" 2>&1
    echo
    journalctl -u "$UNIT" --no-pager -n 60 2>&1
)"

logger -t notify-failure "restic unit ${UNIT} failed"

if mkdir -p "$STATUS_DIR" && printf '%s\n' "$REPORT" > "$FLAG"; then
    chmod 0664 "$FLAG" || true
else
    logger -t notify-failure "could not write ${FLAG}"
fi

# NOTIFY_EMAIL may hold several addresses separated by spaces and/or commas.
read -ra recipients <<< "${NOTIFY_EMAIL//,/ }"
if (( ${#recipients[@]} )) && command -v mail >/dev/null 2>&1; then
    printf '%s\n' "$REPORT" | mail -r "$NOTIFY_FROM" -a "From: Glider backups <${NOTIFY_FROM}>" -s "[backup] ${UNIT} FAILED on $(hostname)" "${recipients[@]}" \
        || logger -t notify-failure "mail to ${recipients[*]} failed"
fi
