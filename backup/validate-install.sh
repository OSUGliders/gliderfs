#!/usr/bin/env bash
# Validate the restic backup install. Read-only: never writes to a repo
# (restic runs with --no-lock) and never starts units.
#
#   ./validate-install.sh                 # any user in glider_t3
#   sudo ./validate-install.sh            # adds checks run as gliderhelper
#   ./validate-install.sh --tree slocum-raw
#   ./validate-install.sh --test-email    # also sends a test email to NOTIFY_EMAIL
#
# Exit status: 0 if no FAIL results, 1 otherwise (WARNs don't fail).

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER=gliderhelper
SERVICE_GROUPS=(glider_t3 glider_group)
STATUS_DIR=/storage/t3/dept/ceoas/grg/backup/STATUS
MAX_SNAPSHOT_AGE_H=36

ONLY_TREE=""
TEST_EMAIL=0
while (( $# )); do
    case $1 in
        --tree) ONLY_TREE="$2"; shift 2 ;;
        --test-email) TEST_EMAIL=1; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ -t 1 ]]; then G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' B=$'\e[1m' N=$'\e[0m'; else G= Y= R= B= N=; fi
nfail=0; nwarn=0
pass() { printf '  %sPASS%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %sWARN%s %s\n' "$Y" "$N" "$*"; nwarn=$((nwarn+1)); }
fail() { printf '  %sFAIL%s %s\n' "$R" "$N" "$*"; nfail=$((nfail+1)); }
section() { printf '\n%s== %s%s\n' "$B" "$*" "$N"; }

# check_file <source-in-setup> <installed-path> <mode>
check_file() {
    local src="$1" dst="$2" mode="$3"
    if [[ ! -e "$dst" ]]; then fail "$dst missing"; return; fi
    local m; m="$(stat -c %a "$dst")"
    if [[ ! -r "$dst" ]]; then fail "$dst not readable by $(id -un) (mode $m)"; return; fi
    if ! cmp -s "$src" "$dst"; then
        fail "$dst differs from $(basename "$src") here (re-run sudo ./install.sh)"
    elif [[ "$m" != "$mode" ]]; then
        warn "$dst mode $m, expected $mode"
    else
        pass "$dst"
    fi
}

# ---------------------------------------------------------------------------
section "Installed files match this directory"
check_file "$SRC/restic-backup.sh"        /usr/local/bin/restic-backup.sh   755
check_file "$SRC/restic-check.sh"         /usr/local/bin/restic-check.sh    755
check_file "$SRC/notify-failure.sh"       /usr/local/bin/notify-failure.sh  755
check_file "$SRC/restic-excludes.txt"     /etc/restic/excludes.txt          644
check_file "$SRC/restic-excludes-raw.txt" /etc/restic/excludes-raw.txt      644
[[ -f "$SRC/notify.env" ]] && check_file "$SRC/notify.env" /etc/restic/notify.env 644
for unit in restic-backup@.service restic-backup@.timer restic-check@.service \
            restic-check@.timer notify-failure@.service; do
    check_file "$SRC/$unit" "/etc/systemd/system/$unit" 644
done
for env in "$SRC"/*.env; do
    [[ "$(basename "$env")" == notify.env ]] && continue
    check_file "$env" "/etc/restic/env/$(basename "$env")" 644
done
for env in /etc/restic/env/*.env; do
    [[ -f "$SRC/$(basename "$env")" ]] || warn "$env is installed but not in setup/"
done

# ---------------------------------------------------------------------------
section "Tools and service account"
if command -v restic >/dev/null; then pass "$(restic version | head -1)"; else fail "restic not on PATH"; fi
if id "$SERVICE_USER" >/dev/null 2>&1; then
    user_groups=" $(id -nG "$SERVICE_USER") "
    for g in "${SERVICE_GROUPS[@]}"; do
        if [[ "$user_groups" == *" $g "* ]]; then pass "$SERVICE_USER in $g"; else fail "$SERVICE_USER not in $g"; fi
    done
else
    fail "user $SERVICE_USER does not exist"
fi

# ---------------------------------------------------------------------------
section "Notifications"
NOTIFY_EMAIL=""
NOTIFY_FROM=""
if [[ -r /etc/restic/notify.env ]]; then
    NOTIFY_EMAIL="$(. /etc/restic/notify.env; printf '%s' "${NOTIFY_EMAIL:-}")"
    NOTIFY_FROM="$(. /etc/restic/notify.env; printf '%s' "${NOTIFY_FROM:-}")"
fi
# Same default as notify-failure.sh
NOTIFY_FROM="${NOTIFY_FROM:-gliderhelper@$(hostname -f)}"
if [[ -n "$NOTIFY_EMAIL" ]]; then pass "NOTIFY_EMAIL: $NOTIFY_EMAIL"; else warn "NOTIFY_EMAIL not set; failures only write flag files"; fi
pass "NOTIFY_FROM: $NOTIFY_FROM"
if command -v mail >/dev/null; then pass "mail command: $(readlink -f "$(command -v mail)")"; else warn "no mail command; emails cannot be sent"; fi
relay="$(postconf -h relayhost 2>/dev/null)"
if [[ -n "$relay" ]]; then pass "postfix relayhost: $relay"; else warn "postfix relayhost not set"; fi
if [[ -d "$STATUS_DIR" ]] && compgen -G "$STATUS_DIR/*.failed" >/dev/null; then
    for f in "$STATUS_DIR"/*.failed; do fail "failure flag present: $f"; done
else
    pass "no failure flags in $STATUS_DIR"
fi
if (( TEST_EMAIL )) && [[ -n "$NOTIFY_EMAIL" ]]; then
    read -ra recipients <<< "${NOTIFY_EMAIL//,/ }"
    if echo "Test notification from $(hostname) validate-install.sh at $(date -Is)" \
        | mail -r "$NOTIFY_FROM" -a "From: Glider backups <${NOTIFY_FROM}>" -s "[backup] test notification from $(hostname)" "${recipients[@]}"; then
        pass "test email handed to mail for: ${recipients[*]} (confirm it arrives)"
    else
        fail "mail command failed sending test email"
    fi
fi

# ---------------------------------------------------------------------------
[[ $(systemctl show -p NeedDaemonReload --value restic-backup@x.service 2>/dev/null) == yes ]] \
    && { section "systemd"; fail "unit files changed on disk: run sudo systemctl daemon-reload"; }

for env in /etc/restic/env/*.env; do
    tree="$(basename "$env" .env)"
    [[ -n "$ONLY_TREE" && "$tree" != "$ONLY_TREE" ]] && continue
    section "Tree: $tree"

    # Load this tree's env file; unset first so values don't leak between trees.
    unset RESTIC_REPOSITORY SOURCE_DIR BACKUP_TAG EXCLUDE_FILE KEEP_DAILY KEEP_WEEKLY KEEP_MONTHLY KEEP_YEARLY
    set -a; . "$env"; set +a
    BACKUP_TAG="${BACKUP_TAG:-$(basename "${SOURCE_DIR:-x}")}"
    EXCLUDE_FILE="${EXCLUDE_FILE:-/etc/restic/excludes.txt}"
    export RESTIC_CACHE_DIR="${TMPDIR:-/tmp}/validate-restic-cache-$(id -u)"

    [[ -n "${RESTIC_REPOSITORY:-}" ]] || { fail "RESTIC_REPOSITORY not set in $env"; continue; }
    [[ -n "${SOURCE_DIR:-}" ]]        || { fail "SOURCE_DIR not set in $env"; continue; }

    # Source, excludes, repo on disk
    if [[ -d "$SOURCE_DIR" && -n "$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        pass "source $SOURCE_DIR present and non-empty"
    else
        fail "source $SOURCE_DIR missing or empty"
    fi
    if [[ -r "$EXCLUDE_FILE" ]]; then pass "exclude file $EXCLUDE_FILE"; else fail "exclude file $EXCLUDE_FILE not readable"; fi
    if [[ -f "$RESTIC_REPOSITORY/config" ]]; then pass "repo $RESTIC_REPOSITORY exists"; else fail "no repo at $RESTIC_REPOSITORY (restic init needed)"; continue; fi

    # Latest snapshot for this tag: age and owner
    snap_json="$(restic --insecure-no-password --no-lock snapshots --json --latest 1 --tag "$BACKUP_TAG" 2>&1)"
    if [[ $? -ne 0 ]]; then
        fail "cannot read repo: ${snap_json##*$'\n'}"
    else
        snap_time="$(grep -o '"time":"[^"]*"' <<< "$snap_json" | tail -1 | cut -d'"' -f4)"
        snap_id="$(grep -o '"id":"[^"]*"' <<< "$snap_json" | tail -1 | cut -d'"' -f4)"
        if [[ -z "$snap_time" ]]; then
            warn "no snapshots with tag $BACKUP_TAG yet"
        else
            age_h=$(( ( $(date +%s) - $(date -d "$snap_time" +%s) ) / 3600 ))
            if (( age_h <= MAX_SNAPSHOT_AGE_H )); then
                pass "latest snapshot ${snap_id:0:8} is ${age_h}h old"
            else
                fail "latest snapshot ${snap_id:0:8} is ${age_h}h old (> ${MAX_SNAPSHOT_AGE_H}h)"
            fi
            owner="$(stat -c %U "$RESTIC_REPOSITORY/snapshots/$snap_id" 2>/dev/null)"
            if [[ "$owner" == "$SERVICE_USER" ]]; then pass "latest snapshot written by $SERVICE_USER"
            else warn "latest snapshot written by ${owner:-?}, not $SERVICE_USER"; fi
        fi
    fi

    # Timers
    for kind in backup check; do
        timer="restic-${kind}@${tree}.timer"
        state="$(systemctl is-enabled "$timer" 2>/dev/null)"
        if [[ "$state" == enabled ]] && systemctl is-active -q "$timer"; then
            next="$(systemctl list-timers --all --no-legend "$timer" 2>/dev/null | awk '{print $1,$2,$3,$4}')"
            pass "$timer enabled, next: ${next:-?}"
        else
            fail "$timer is ${state:-unknown}/$(systemctl is-active "$timer" 2>/dev/null) (sudo systemctl enable --now $timer)"
        fi
    done

    # Service state (Result resets when the unit is garbage-collected, so only
    # a present failure is meaningful)
    for kind in backup check; do
        svc="restic-${kind}@${tree}.service"
        active="$(systemctl show -p ActiveState --value "$svc" 2>/dev/null)"
        result="$(systemctl show -p Result --value "$svc" 2>/dev/null)"
        case "$active" in
            activating) pass "$svc currently running" ;;
            failed)     fail "$svc last run failed (result: $result)" ;;
            *)          pass "$svc not failed ($active)" ;;
        esac
    done

    # Cache
    cache="/var/cache/restic/$tree"
    if [[ -d "$cache" ]]; then
        owner="$(stat -c %U "$cache")"
        if [[ "$owner" == "$SERVICE_USER" ]]; then pass "cache $cache owned by $SERVICE_USER"; else warn "cache $cache owned by $owner"; fi
    else
        warn "cache $cache not created yet (created on first service run)"
    fi

    # Checks that must run as the service account
    if (( EUID == 0 )); then
        as_svc() { sudo -u "$SERVICE_USER" "$@"; }
        if as_svc test -r "$SOURCE_DIR" -a -x "$SOURCE_DIR"; then pass "$SERVICE_USER can read $SOURCE_DIR"; else fail "$SERVICE_USER cannot read $SOURCE_DIR"; fi
        # Symlinks are skipped: -readable follows them, so a dangling link (e.g.
        # an emacs .#lock) looks unreadable, while restic just stores the link.
        unreadable="$(as_svc find "$SOURCE_DIR" \( \( ! -type l ! -readable \) -o \( -type d ! -executable \) \) -print -quit 2>/dev/null)"
        if [[ -z "$unreadable" ]]; then pass "$SERVICE_USER can read everything under $SOURCE_DIR"
        else fail "$SERVICE_USER cannot read e.g. $unreadable"; fi
        for d in "$RESTIC_REPOSITORY/data" "$RESTIC_REPOSITORY/locks" "$RESTIC_REPOSITORY/snapshots" "$(dirname "$STATUS_DIR")"; do
            if as_svc test -w "$d"; then pass "$SERVICE_USER can write $d"; else fail "$SERVICE_USER cannot write $d"; fi
        done
    else
        printf '  (run with sudo to also test %s read/write access)\n' "$SERVICE_USER"
    fi
done

rm -rf "${TMPDIR:-/tmp}/validate-restic-cache-$(id -u)"

printf '\n%s%d FAIL, %d WARN%s\n' "$B" "$nfail" "$nwarn" "$N"
(( nfail == 0 ))
