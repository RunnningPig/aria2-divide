#!/usr/bin/env bash
#
# vim: noai:ts=2:sw=2
# $1: gid
# $2: the number of files
# $3: file path
set -o nounset -o errexit -o pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
LOGFILE="${SCRIPT_PATH}/aria2_download_start.log"

. "${SCRIPT_PATH}/core/aria2.sh"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $@" >> "${LOGFILE}"
}

haveEnoughCapacity() {
  local avail_length="$(df --output=avail / | command tail -1)"
  local total_length="$(aria2.getActiveTotalLength)"
  local completed_length="$(aria2.getActiveCompletedLength)"
  [[ "$((${total_length}-${completed_length}))" -lt "${avail_length}000" ]]
}

log "gid:$1"

if ! haveEnoughCapacity; then
  if ! aria2.autoSelectFiles "$1" "$(aria2.next "$1")"; then
    aria2.forcePause "$1"
    aria2.unpauseWaiting
  fi
fi
