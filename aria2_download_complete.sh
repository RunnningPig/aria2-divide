#!/usr/bin/env bash
#
# vim: noai:ts=2:sw=2
# $1: GID
# $2: the number of files
# $3: file path
set -o nounset -o errexit -o pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
LOGFILE="${SCRIPT_PATH}/aria2_download_complete.log"

. "${SCRIPT_PATH}/core/aria2.sh"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $@" >> "${LOGFILE}"
}

remove_finished() {
  local download_path="$(aria2.getDownloadPath)"
  local file="${1-}"
  local parent="${file%/*}"
  while [[ "${parent:-/}" != '/' && "${parent}" != "${download_path}" ]]; do
    file="${parent}"
    parent="${file%/*}"
  done
  [[ "${parent}" == "${download_path}" ]] && rm -rf "${file}" || true
}

continue_unfinished() {
  local offset="$(aria2.next "$1")"
  [[ "${offset}" -eq -1 ]] && return 1

  local hash="$(aria2.getInfoHash "$1")"
  local uri="magnet:?xt=urn:btih:${hash}"
  local gid="$(aria2.addUri "${uri}" "pause-metadata" "true")"
  while [[ "$(aria2.getChildrenNumber "${gid}")" -eq 0 ]]; do sleep 5; done
  local newgid="$(aria2.tellStatus "${gid}" followedBy \
    | jq -crM '.followedBy[0]')"

  log "offset:${offset} hash:${hash} newgid:${newgid}"

  aria2.autoSelectFiles "${newgid}" "${offset}" && aria2.unpause "${newgid}"
}

execute_user_action() {
  USER_ACTION="${SCRIPT_PATH}/user_action"
  [[ -e "${USER_ACTION}" ]] && "${USER_ACTION}" "$@" || true
}

log "gid:$1"

# 过滤磁力链接元数据
[[ "$(aria2.getChildrenNumber "$1")" -gt 0 ]] && exit 0

execute_user_action "$@"

remove_finished "${3-}"
if ! continue_unfinished "$1"; then
  aria2.unpauseWaiting
fi
