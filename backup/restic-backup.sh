#!/usr/bin/env bash
# Generic restic backup wrapper, driven entirely by environment variables
# supplied via a systemd EnvironmentFile (see restic-backup@.service).
#
# Runs `backup` then `forget` (no prune). Pruning is done weekly by
# restic-check.sh so the expensive exclusive-lock work happens in one place.
#
# Required env vars:
#   RESTIC_REPOSITORY     - repo path/URL for this tree
#   SOURCE_DIR            - directory to back up
# Optional:
#   BACKUP_TAG            - tag for this snapshot set (default: basename of SOURCE_DIR)
#   EXCLUDE_FILE          - default /etc/restic/excludes.txt
#   KEEP_DAILY/KEEP_WEEKLY/KEEP_MONTHLY/KEEP_YEARLY
#                         - retention counts ("unlimited" allowed). Unset uses the
#                           defaults below; set to empty (KEEP_YEARLY=) to disable.
#   RESTIC_UNIT           - systemd unit name (set by the service); used to clear
#                           the failure flag written by notify-failure.sh
#   STATUS_DIR            - default /storage/t3/dept/ceoas/grg/backup/STATUS
#
# Exit codes: 0 ok; 3 snapshot saved but some files were unreadable (e.g. an
# NFS hiccup on the soft-mounted source); anything else is a hard failure.
#
# NOTE: repos are unencrypted/passwordless (--insecure-no-password), by
# request. This is only appropriate because these repos live on storage
# you already trust and control access to (T3 filesystem permissions
# are the real access control here, not restic's encryption).

set -uo pipefail

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY must be set}"
: "${SOURCE_DIR:?SOURCE_DIR must be set}"

RESTIC_OPTS=(--insecure-no-password --retry-lock 2h)

BACKUP_TAG="${BACKUP_TAG:-$(basename "$SOURCE_DIR")}"
EXCLUDE_FILE="${EXCLUDE_FILE:-/etc/restic/excludes.txt}"
KEEP_DAILY="${KEEP_DAILY-14}"
KEEP_WEEKLY="${KEEP_WEEKLY-8}"
KEEP_MONTHLY="${KEEP_MONTHLY-12}"
KEEP_YEARLY="${KEEP_YEARLY-5}"
STATUS_DIR="${STATUS_DIR:-/storage/t3/dept/ceoas/grg/backup/STATUS}"
LOG_TAG="restic-backup-${BACKUP_TAG}"

log() { logger -t "$LOG_TAG" "$*"; echo "[$LOG_TAG] $*"; }
die() { log "ERROR: $*"; exit 1; }

# --- pre-flight: never snapshot a missing/unmounted/empty source ---
[[ -d "$SOURCE_DIR" ]] || die "SOURCE_DIR ${SOURCE_DIR} does not exist"
[[ -n "$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]] \
    || die "SOURCE_DIR ${SOURCE_DIR} is empty (unmounted?)"
[[ -r "$EXCLUDE_FILE" ]] || die "EXCLUDE_FILE ${EXCLUDE_FILE} not readable"

log "starting backup of ${SOURCE_DIR}"

restic "${RESTIC_OPTS[@]}" backup "$SOURCE_DIR" \
    --exclude-file="$EXCLUDE_FILE" \
    --exclude-caches \
    --one-file-system \
    --tag "$BACKUP_TAG"
rc=$?

case $rc in
    0) log "backup complete" ;;
    3) log "WARNING: snapshot saved but some source files could not be read (see above)" ;;
    *) die "backup failed (restic exit ${rc})" ;;
esac

keep=()
[[ -n "$KEEP_DAILY"   ]] && keep+=(--keep-daily "$KEEP_DAILY")
[[ -n "$KEEP_WEEKLY"  ]] && keep+=(--keep-weekly "$KEEP_WEEKLY")
[[ -n "$KEEP_MONTHLY" ]] && keep+=(--keep-monthly "$KEEP_MONTHLY")
[[ -n "$KEEP_YEARLY"  ]] && keep+=(--keep-yearly "$KEEP_YEARLY")
(( ${#keep[@]} )) || die "no KEEP_* retention set; refusing to forget everything"

log "applying retention policy: ${keep[*]}"
restic "${RESTIC_OPTS[@]}" forget --tag "$BACKUP_TAG" "${keep[@]}" \
    || die "forget failed"

# Incomplete snapshot: fail the unit so OnFailure notifies someone.
(( rc == 3 )) && exit 3

[[ -n "${RESTIC_UNIT:-}" ]] && rm -f "${STATUS_DIR}/${RESTIC_UNIT}.failed"
log "done"
