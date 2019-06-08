#!/usr/bin/env bash
#
# vim: noai:ts=2:sw=2
set -o nounset -o errexit -o pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"

bash "${SCRIPT_PATH}/core/aria2.sh" test

