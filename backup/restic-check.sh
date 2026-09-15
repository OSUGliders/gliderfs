#!/usr/bin/env bash
# Weekly maintenance for a restic repo: prune unreferenced data (left behind
# by the daily `forget`), then verify integrity.
#
# The data check reads a rotating 1/4 of the packs each run, keyed on ISO
# week number, so every pack is re-read roughly once every 4 weeks.
#
# Required env vars:
#   RESTIC_REPOSITORY
# Optional:
#   RESTIC_UNIT   - systemd unit name (set by the service); clears failure flag
#   STATUS_DIR    - default /storage/t3/dept/ceoas/grg/backup/STATUS
#
# NOTE: repo is unencrypted/passwordless (--insecure-no-password), by request.

set -euo pipefail

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY must be set}"

RESTIC_OPTS=(--insecure-no-password --retry-lock 2h)
STATUS_DIR="${STATUS_DIR:-/storage/t3/dept/ceoas/grg/backup/STATUS}"

LOG_TAG="restic-check-$(basename "$RESTIC_REPOSITORY")"
log() { logger -t "$LOG_TAG" "$*"; echo "[$LOG_TAG] $*"; }

# 10# forces base 10: %V is zero-padded and "08"/"09" are invalid octal.
subset="$(( 10#$(date +%V) % 4 + 1 ))/4"

log "pruning"
restic "${RESTIC_OPTS[@]}" prune

log "starting integrity check (data subset ${subset})"
restic "${RESTIC_OPTS[@]}" check --read-data-subset="$subset"

[[ -n "${RESTIC_UNIT:-}" ]] && rm -f "${STATUS_DIR}/${RESTIC_UNIT}.failed"
log "check complete"
