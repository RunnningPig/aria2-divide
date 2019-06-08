#!/usr/bin/env bash
#
# vim: noai:ts=2:sw=2
# pure bash library for aria2
set -o nounset -o errexit -o pipefail
IFS=$'\n\t'

ARIA2_SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
ARIA2LOG="${ARIA2_SCRIPT_PATH}/aria2.log"

aria2.log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $@" >> "${ARIA2LOG}"
}

##################################################
# 索引数组转 json 数组
# 全局变量：
#   无
# 参数：
#   [$@]：索引数组
# 返回值：
#   json 数组
##################################################
aria2.toJsonArray() {
  [[ "$#" -eq 0 ]] && { echo []; return; }
  printf '%s\n' "$@" | jq -R '. | (tonumber? // .)' | jq -cMrs '.'
}

##################################################
# 关联数组转 json 对象
# 全局变量：
#   无
# 参数：
#   [$@]：关联数组（key1 key2 .. val1 val2 ..）
# 返回值：
#   json 对象（{key1:valu1,key2:val2,..}）
##################################################
aria2.toJsonMap() {
  [[ "$#" -eq 0 ]] && { echo {}; return; }
  printf '%s\0' "$@" | jq -cMRs 'split("\u0000") | . as $v | (length / 2) as $n
    | reduce range($n) as $i ({}; .[$v[$i]]=($v[$i+$n] | (tonumber? // .)))'
}

##################################################
# 添加 uri 任务
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：uri 链接
#   [$@:2]：任务选项
# 返回值：
#   任务 gid
##################################################
aria2.addUri() {
  local jsonreq="$(jq -cMn \
                    --arg token "token:${RPC_SECRET}" \
                    --arg uri "$1" \
                    --argjson options "$(aria2.toJsonMap "${@:2}")" \
                    '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.addUri",
                      "params":[$token, [$uri], $options]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 强制暂停任务
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   任务 gid
##################################################
aria2.forcePause() {
  local jsonreq="$(jq -cMn \
                    --arg token "token:${RPC_SECRET}" \
                    --arg gid "$1" \
                    '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.forcePause",
                      "params":[$token, $gid]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 取消暂停任务
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   任务 gid
##################################################
aria2.unpause() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --arg gid "$1" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.unpause",
                     "params":[$token, $gid]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询任务信息
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
#   [$@:2]：过滤字段列表（https://aria2.github.io/manual/en/html/aria2c.html#aria2.tellStatus）
# 返回值：
#   任务信息（json 对象）
##################################################
aria2.tellStatus() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --arg gid "$1" \
                   --argjson keys "$(aria2.toJsonArray "${@:2}")" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.tellStatus",
                     "params":[$token, $gid, $keys]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询 uri 列表
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   uri 列表（json 对象）
##################################################
aria2.getUris() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --arg gid "$1" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.getUris",
                     "params":[$token, $gid]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询文件列表
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   文件列表（json 对象）
##################################################
aria2.getFiles() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --arg gid "$1" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.getFiles",
                     "params":[$token, $gid]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询下载队列中所有任务的信息
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   [$@]：过滤字段列表（https://aria2.github.io/manual/en/html/aria2c.html#aria2.tellActive）
# 返回值：
#   所有任务信息（json 数组）
##################################################
aria2.tellActive() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --argjson keys "$(aria2.toJsonArray "$@")" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.tellActive",
                     "params":[$token, $keys]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询等待队列中所有任务的信息（包括暂停队列）
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：偏移量
#   $2：任务数量
#   [$@:3]：过滤字段列表（https://aria2.github.io/manual/en/html/aria2c.html#aria2.tellWaiting）
# 返回值：
#   所有任务信息（json 数组）
##################################################
aria2.tellWaiting() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --argjson offset "$1" \
                   --argjson num "$2" \
                   --argjson keys "$(aria2.toJsonArray "${@:3}")" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.tellWaiting",
                     "params":[$token, $offset, $num, $keys]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 查询停止队列中所有任务的信息
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：偏移量
#   $2：任务数量
#   [$@:3]：过滤字段列表（https://aria2.github.io/manual/en/html/aria2c.html#aria2.tellStopped）
# 返回值：
#   所有任务信息（json 数组）
##################################################
aria2.tellStopped() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --argjson offset "$1" \
                   --argjson num "$2" \
                   --argjson keys "$(aria2.toJsonArray "${@:3}")" \
                   '{"id":"qwer", "jsonrpc":"2.0","method":"aria2.tellStopped",
                     "params":[$token, $offset, $num, $keys]}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)'
}

##################################################
# 更改任务选项
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
#   ${@:2}：选项列表（key1 key2 .. val1 val2 ..）
# 返回值：
#   成功：0
##################################################
aria2.changeOption() {
  local jsonreq="$(jq -cMn \
                   --arg token "token:${RPC_SECRET}" \
                   --arg gid "$1" \
                   --argjson options "$(aria2.toJsonMap "${@:2}")" \
                   '{"id":"qwer", "jsonrpc":"2.0",
                     "method":"aria2.changeOption",
                     "params":[$token, $gid, $options]}')"
  [[ "$(curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq -cMr '.result | select(.!=null)')" == 'OK' ]]
}

##################################################
# 查询可用通知
# 全局变量：
#   RPC_ADDRESS：rpc 地址
# 参数：
#   无
# 返回值：
#   可用通知列表
##################################################
aria2.listNotifications() {
  local jsonreq="$(jq -cMn \
                   '{"id":"qwer", "jsonrpc":"2.0",
                     "method":"system.listNotifications"}')"
  curl -sSd "${jsonreq}" "${RPC_ADDRESS}" \
    | jq  -cMr '.result | select(.!=null)'
}

##################################################
# 选择文件
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
#   ${@:2}：文件索引（0-base）
# 返回值：
#   成功：0
##################################################
aria2.selectFiles() {
  for i in "${@:2}"; do local l="$(($i+1)),${l-}"; done
  aria2.changeOption "$1" 'select-file' "$l"
}

##################################################
# 查询下载队列中文件总大小
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   无
# 返回值：
#   文件大小
##################################################
aria2.getActiveTotalLength() {
  aria2.tellActive totalLength | \
    jq 'reduce .[].totalLength as $len (0; .+($len|tonumber))'
}

##################################################
# 查询下载队列中文件已下载总大小
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   无
# 返回值：
#   文件大小
##################################################
aria2.getActiveCompletedLength() {
  aria2.tellActive completedLength | \
    jq 'reduce .[].completedLength as $len (0; .+($len|tonumber))'
}

##################################################
# 查询任务状态
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   任务状态
##################################################
aria2.getStatus() {
  aria2.tellStatus "$1" status | jq -cMr '.status'
}

##################################################
# 查询任务文件大小
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   文件大小
##################################################
aria2.getTotalLength() {
  aria2.tellStatus "$1" totalLength | jq -cMr '.totalLength'
}

##################################################
# 查询任务的第一个文件索引（逻辑上）
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   文件索引（0-base）
##################################################
aria2.next() {
  local status="$(aria2.getStatus "$1")"
  local selecteds=($(aria2.getFiles "$1" | jq -cMr '.[].selected'))
  if [[ "${status}" == 'complete' ]]; then
    for ((i="${#selecteds[@]}"-1; i >= 0; i--)); do
      [[ "${selecteds[$i]}" == 'true' ]] && break
    done
    [[ "$i" -lt "${#selecteds[@]}"-1 ]] && echo "$(($i+1))" || echo -1
  else
    for ((i=0; i < "${#selecteds[@]}"; i++)); do
      [[ "${selecteds[$i]}" == 'true' ]] && break
    done
    [[ "$i" -lt "${#selecteds[@]}" ]] && echo "$i" || echo -1
  fi
}

##################################################
# 查询原始下载链接
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   原始下载链接
##################################################
aria2.getOriginUri() {
  local parent="$(aria2.tellStatus "$1" following \
    | jq -cMr '.following | select(.!=null)')"
  aria2.getFiles "${parent}" | jq -cMr '.[0].uris[0].uri | select(.!=null)'
}

##################################################
# 从给定位置起，依次选择满足当前可用磁盘的文件
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
#   [$2]：文件偏移量，默认 0
# 返回值：
#   成功：0
##################################################
aria2.autoSelectFiles() {
  [[ "${2-0}" -lt 0 ]] && return 1
  local status="$(aria2.getStatus "$1")"
  local avail_length="$(df --output=avail / | command tail -1)"
  local lengths=($(aria2.getFiles "$1" | jq -cMr '.[].length'))
  local length="$(aria2.getActiveTotalLength)"
  local -a indexs
  if [[ "${status}" == 'active' ]]; then
    length="$((${length}-$(aria2.getTotalLength "$1")))"
  fi
  for ((i="${2-0}"; i < "${#lengths[@]}"; i++)); do
    length="$((${length}+${lengths[$i]}))"
    [[ "${length}" -gt "${avail_length}"*1000 ]] && break
    indexs+=("$i")
  done
  if [[ "${#indexs[@]}" -gt 0 ]]; then
    aria2.selectFiles "$1" "${indexs[@]}"
    return 0
  else
    aria2.selectFiles "$1" "${2-0}-1024"
    return 1
  fi
}

##################################################
# 解放等待队列中的任务（任务需满足 autoSelectFiles）
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   无
# 返回值：
#   成功解放的任务列表
##################################################
aria2.unpauseWaiting() {
  local gids=($(aria2.tellWaiting 0 1000 gid | jq -cMr '.[].gid'))
  [[ "${#gids[@]}" -eq 0 ]] && return 0
  for gid in "${gids[@]}"; do
    local offset="$(aria2.next "${gid}")"
    aria2.autoSelectFiles "${gid}" "${offset}" && aria2.unpause "${gid}"
  done
}

##################################################
# 查询子任务数
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   子任务数
##################################################
aria2.getChildrenNumber() {
  aria2.tellStatus "$1" followedBy | jq '.followedBy | length'
}

##################################################
# 查询哈希值
# 全局变量：
#   RPC_SECRET：rpc 密钥
#   RPC_ADDRESS：rpc 地址
# 参数：
#   $1：任务 gid
# 返回值：
#   哈希值
##################################################
aria2.getInfoHash() {
  aria2.tellStatus "$1" infoHash | jq -cMr '.infoHash'
}

##################################################
# 查询 RPC 密钥
# 全局变量：
#   ARIA2CONFIG：aria2 配置文件
# 参数：
#   无
# 返回值：
#   RCP 密钥
##################################################
aria2.getRPCSecret() {
  grep -oP '(?<=^rpc-secret=).*' "${ARIA2CONFIG}"
}

##################################################
# 查询 RPC 是否开启 ssl 加密
# 全局变量：
#   ARIA2CONFIG：aria2 配置文件
# 参数：
#   无
# 返回值：
#   0：开启状态
#   1：关闭状态
##################################################
aria2.isRPCEncryption() {
  [[ "$(grep -oP "(?<=^rpc-secure=).+" "${ARIA2CONFIG}")" == true ]]
}

##################################################
# 查询 RPC 主机名
# 全局变量：
#   ARIA2CONFIG：aria2 配置文件
# 参数：
#   无
# 返回值：
#   主机名
##################################################
aria2.getRCPHost() {
  if aria2.isRPCEncryption; then
    grep -oP '(?<=^rpc-certificate=/etc/letsencrypt/live/)[^/]*' "${ARIA2CONFIG}"
  else
    echo "localhost"
  fi
}

##################################################
# 查询 RPC 端口号
# 全局变量：
#   ARIA2CONFIG：aria2 配置文件
# 参数：
#   无
# 返回值：
#   端口号
##################################################
aria2.getRCPPort() {
  grep -oP '(?<=^rpc-listen-port=)[0-9]*' "${ARIA2CONFIG}"
}

##################################################
# 获取 aria2 配置文件路径
# 参数：
#   无
# 返回值：
#   文件路径
##################################################
aria2.getConfPath() {
  if [[ -e "${HOME}/.aria2/aria2.conf" ]]; then
    echo "${HOME}/.aria2/aria2.conf"
  else
    echo "$XDG_CONFIG_HOME/aria2/aria2.conf"
  fi
}

##################################################
# 获取下载路径
# 参数：
#   无
# 返回值：
#   下载路径
##################################################
aria2.getDownloadPath() {
  grep -oP '(?<=^dir=).+' "${ARIA2CONFIG}"
}


##################################################
# 配置测试
# 参数：
#   无
# 返回值：
#   文件路径
##################################################
aria2.test() {
  Green_font_prefix="\033[32m"
  Red_font_prefix="\033[31m"
  Font_color_suffix="\033[0m"
  Info="${Green_font_prefix}[信息]${Font_color_suffix}"
  Error="${Red_font_prefix}[错误]${Font_color_suffix}"
  echo -e "Aria2 相关信息："
  echo -e
  echo -e "\t配置文件: ${Green_font_prefix}${ARIA2CONFIG}${Font_color_suffix}"
  echo -e "\tRPC 地址: ${Green_font_prefix}${RPC_ADDRESS}${Font_color_suffix}"
  echo -e "\tRPC 密钥: ${Green_font_prefix}${RPC_SECRET:-无密钥}${Font_color_suffix}"
  echo -e
  if [[ -n "$(aria2.tellActive)" ]]; then
    echo -e "${Info}：测试配置成功！"
  else
    echo -e "${Error}：测试配置失败！"
  fi
}


if [[ -z "${ARIA2CONFIG-}" ]]; then
  declare -r ARIA2CONFIG="$(aria2.getConfPath)"
fi
if aria2.isRPCEncryption; then
  declare -r RPC_PROTOCOL="https"
else
  declare -r RPC_PROTOCOL="http"
fi
# 如果开启了 RPC 的 SSL 加密
# 请将下面的 RPC_HOST 改成对应的域名
declare -r RPC_HOST="$(aria2.getRCPHost)"
declare -r RPC_PORT="$(aria2.getRCPPort)"
declare -r RPC_ADDRESS="${RPC_PROTOCOL}://${RPC_HOST}:${RPC_PORT}/jsonrpc"
declare -r RPC_SECRET="$(aria2.getRPCSecret)"

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  aria2."${1-test}" "${@:2}"
fi
