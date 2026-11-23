#!/usr/bin/env bash
# ============================================================
# tools/files_manage.sh — Cross-Device File Management Helper
# ============================================================
# SSOT: All node vars come from core/00-env.sh (NODE_*)
# Transport: uses _rsync_to / _rsync_from / _rsync_to_delete
#            (defined in core/3worlds.sh)
#
# Nodes: dynamic — ทุก bootstrap/nodes/<name>.node.env (termux | wsl | wsl2 |
#        window | mumu | oppo | redmi | acodex | git-bash | gcloud | …)
#        พร้อม alias จาก core/node-mesh.sh (ssot_node_resolve)
#
# Public API (frozen signatures):
#   fm_send  <node> <local_src>   [remote_dst]  - push  local -> remote
#   _fm_node_pull <node> <remote_src> [local_dst] - pull remote -> local
#   fm_sync  <node> <local_src>   [remote_dst]  - mirror local -> remote (--delete)
#   _fm_node_mv <node> <local_src> <remote_dst> - move local -> remote (rm local after)
#   _fm_node_ls <node> [remote_path]            - list  remote path
#   _fm_node_rm <node> <remote_path>            - remove file/dir on remote
#   fm_exec  <node> <cmd...>                    - run arbitrary cmd on remote
#   _fm_node_info                               - show all node connection info
#   fm_check <node|all>                         - ping / connectivity test
#   fn       [action] [args...]                 - cross-device dispatcher
#   fmx      [action] [args...]                 - alias of fn
# ============================================================

# Guard: avoid double-load
[[ -n "${_FM_LOADED:-}" ]] && return 0
_FM_LOADED=1

# Dependency: if 3worlds transport not loaded, define stubs
# These stubs auto-detect rsync availability (Git Bash → scp fallback)
if ! declare -f _rsync_to &>/dev/null; then
  _SSOT_HAS_RSYNC=0
  command -v rsync >/dev/null 2>&1 && _SSOT_HAS_RSYNC=1
  _rsync_to() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    if [[ "$_SSOT_HAS_RSYNC" -eq 1 ]]; then
      rsync -az --update --info=progress2 -e "ssh -p ${port}" "$src" "${user}@${host}:${dst}"
    else
      scp -P "${port}" -r "$src" "${user}@${host}:${dst}"
    fi
  }
  _rsync_to_delete() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    if [[ "$_SSOT_HAS_RSYNC" -eq 1 ]]; then
      rsync -az --delete --info=progress2 -e "ssh -p ${port}" "$src" "${user}@${host}:${dst}"
    else
      echo "⚠️  scp: no --delete mode, doing plain copy" >&2
      scp -P "${port}" -r "$src" "${user}@${host}:${dst}"
    fi
  }
  _rsync_from() {
    local user="$1" host="$2" port="$3" src="$4" dst="$5"
    if [[ "$_SSOT_HAS_RSYNC" -eq 1 ]]; then
      rsync -az --update --info=progress2 -e "ssh -p ${port}" "${user}@${host}:${src}" "$dst"
    else
      scp -P "${port}" -r "${user}@${host}:${src}" "$dst"
    fi
  }
fi

# ============================================================
# SECTION 0: INTERNAL NODE RESOLVER
# ============================================================
# _fm_node_vars <node_alias>
#   Sets: _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
#   _FM_PROTO = rsync | scp  (MUMU has no rsync)
_fm_node_vars() {
  local node="${1:-}"
  [[ -z "$node" ]] && { cn 196 b "fm: node required"; return 1; }

  # Registry-driven: ทุก device ที่มี bootstrap/nodes/<name>.node.env
  if declare -f ssot_node_resolve >/dev/null 2>&1 && ssot_node_resolve "$node"; then
    _FM_USER="$SSOT_NODE_USER"
    _FM_HOST="$SSOT_NODE_HOST"
    _FM_PORT="${SSOT_NODE_PORT:-22}"
    _FM_PROTO="$SSOT_NODE_PROTO"
    _FM_TAG="$SSOT_NODE_TAG"
    return 0
  fi

  cn 196 b "fm: unknown node '${node}'"
  cn 252   "  registered: $(ssot_node_names 2>/dev/null | tr '\n' ' ')"
  return 1
}

# Print transfer banner
_fm_banner() {
  local dir="$1" tag="$2" src="$3" dst="$4"
  c 226 b "${dir} "
  c 82 b "[${tag}]"
  printf " %s" "$src"
  c 245 " -> "
  cn 87 "$dst"
}

# ============================================================
# SECTION 1: PUBLIC API
# ============================================================

# fm_send <node> <local_src> [remote_dst]
#   Push local file/folder -> remote node (--update, no overwrite of newer)
fm_send() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_send <node> <local_src> [remote_dst]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "SEND" "$_FM_TAG" "$src" "${_FM_HOST}:${dst}"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_to "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    scp -P "$_FM_PORT" -r "$src" "${_FM_USER}@${_FM_HOST}:${dst}"
  fi
}

# fm_pull <node> <remote_src> [local_dst]
#   Pull file/folder from remote -> local (--update, no overwrite of newer)
_fm_node_pull() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_pull <node> <remote_src> [local_dst]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "PULL" "$_FM_TAG" "${_FM_HOST}:${src}" "$dst"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_from "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    scp -P "$_FM_PORT" -r "${_FM_USER}@${_FM_HOST}:${src}" "$dst"
  fi
}

# fm_sync <node> <local_src> [remote_dst]
#   Mirror local -> remote (--delete: remote matches local exactly)
#   WARNING: Destructive on destination
fm_sync() {
  local node="${1:-}" src="${2:-}" dst="${3:-.}"
  [[ -z "$node" || -z "$src" ]] && {
    cn 208 "Usage: fm_sync <node> <local_src> [remote_dst]"
    cn 208 "  -- --delete: files on remote NOT in local_src will be removed"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  _fm_banner "SYNC" "$_FM_TAG" "$src" "${_FM_HOST}:${dst}"
  cn 208 "  -- mirror mode (destination will match source exactly)"

  if [[ "$_FM_PROTO" == "rsync" ]]; then
    _rsync_to_delete "$_FM_USER" "$_FM_HOST" "$_FM_PORT" "$src" "$dst"
  else
    cn 208 "  -- scp has no --delete; doing plain copy"
    scp -P "$_FM_PORT" -r "$src" "${_FM_USER}@${_FM_HOST}:${dst}"
  fi
}

# fm_mv <node> <local_src> <remote_dst>
#   Move: push then delete local (only deletes if transfer succeeded)
_fm_node_mv() {
  local node="${1:-}" src="${2:-}" dst="${3:-}"
  [[ -z "$node" || -z "$src" || -z "$dst" ]] && {
    cn 208 "Usage: fm_mv <node> <local_src> <remote_dst>"
    return 1
  }
  fm_send "$node" "$src" "$dst" && {
    cn 226 "Removing local: $src"
    rm -rf -- "$src"
  }
}

# fm_ls <node> [remote_path]
#   List files on remote node
_fm_node_ls() {
  local node="${1:-}" path="${2:-~}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_ls <node> [remote_path]"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 75 b "[$_FM_TAG] ls ${path}"
  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "ls -lah '${path}' 2>/dev/null || ls -lah ~"
}

# fm_rm <node> <remote_path>
#   Remove a file or directory on remote (asks confirmation)
_fm_node_rm() {
  local node="${1:-}" rpath="${2:-}"
  [[ -z "$node" || -z "$rpath" ]] && {
    cn 208 "Usage: fm_rm <node> <remote_path>"
    return 1
  }
  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 196 b "REMOVE on [$_FM_TAG]: ${rpath}"
  read -rp "  Confirm? [y/N]: " _confirm
  [[ "$_confirm" =~ ^[Yy]$ ]] || { cn 252 "  Cancelled."; return 0; }

  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "rm -rf '${rpath}' && echo 'Removed: ${rpath}'"
}

# fm_exec <node> <cmd...>
#   Run arbitrary command on remote node
fm_exec() {
  local node="${1:-}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_exec <node> <command...>"
    return 1
  }
  shift
  [[ $# -eq 0 ]] && { cn 208 "fm_exec: no command given"; return 1; }

  local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
  _fm_node_vars "$node" || return 1

  cn 245 "[$_FM_TAG] exec: $*"
  ssh -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" "$@"
}

# fm_check <node|all>
#   Connectivity test: SSH ping with 3s timeout
fm_check() {
  local node="${1:-}"
  [[ -z "$node" ]] && {
    cn 208 "Usage: fm_check <node>  (or: fm_check all)"
    return 1
  }

  _fm_ping_one() {
    local _FM_USER _FM_HOST _FM_PORT _FM_PROTO _FM_TAG
    _fm_node_vars "$1" 2>/dev/null || return 1
    printf "  %-10s %s@%s:%s  " "$_FM_TAG" "$_FM_USER" "$_FM_HOST" "$_FM_PORT"
    if ssh -o ConnectTimeout=3 -o BatchMode=yes \
           -p "$_FM_PORT" "${_FM_USER}@${_FM_HOST}" \
           "echo ok" &>/dev/null; then
      cn 82 "ONLINE"
    else
      cn 196 "OFFLINE"
    fi
  }

  if [[ "$node" == "all" ]]; then
    cn 226 b "-- Connectivity Check --"
    local n
    for n in $(ssot_node_names); do
      _fm_ping_one "$n"
    done
  else
    _fm_ping_one "$node"
  fi
  unset -f _fm_ping_one
}

# fm_info
#   Show every registered node (bootstrap/nodes/*.node.env)
_fm_node_info() {
  cn 226 b "-- Node Registry (bootstrap/nodes/*.node.env) --"
  printf "  %-26s %-24s %-16s %-6s %s\n" "NODE" "HOST" "USER" "PORT" "PROTO"
  printf '  %s\n' "$(printf '%.0s-' {1..78})"
  local n mark
  for n in $(ssot_node_names); do
    ssot_node_resolve "$n" || continue
    mark=""
    [[ "${SSOT_NODE_LOCAL:-0}" == "1" ]] && mark=" *"
    printf "  %-26s %-24s %-16s %-6s %s\n" \
      "${n}${mark}" "${SSOT_NODE_HOST}" "${SSOT_NODE_USER}" \
      "${SSOT_NODE_PORT}" "${SSOT_NODE_PROTO}"
  done
  printf "  %-26s %-24s %-16s %-6s %s\n" "local" "localhost" "${USER:-$(id -un)}" "-" "rsync"
  printf '  %s\n' "$(printf '%.0s-' {1..78})"
  cn 252 "  * = this device (MY_DEVICE=${MY_DEVICE:-?})"
}

# ============================================================
# SECTION 2: INTERACTIVE DISPATCHER
# ============================================================
# fm [action] [args...]
#   One-stop entry point. Wraps all fm_* functions.
#
#   fn                            - show help
#   fn info                       - list every registered node
#   fn check [node|all]           - fm_check
#   fn send  <node> <src> [dst]   - fm_send
#   fn pull  <node> <src> [dst]   - _fm_node_pull
#   fn sync  <node> <src> [dst]   - fm_sync
#   fn mv    <node> <src> <dst>   - _fm_node_mv
#   fn ls    <node> [path]        - _fm_node_ls
#   fn rm    <node> <path>        - _fm_node_rm
#   fn exec  <node> <cmd...>      - fm_exec
#   fn bkp   <file...>            - backup (calls bkp from backup.sh)
#
# Also reachable through fm():  fm send|check|sync|exec ...  (delegated)
fn() {
  local action="${1:-}"
  [[ -z "$action" ]] && { _fm_help; return 0; }
  shift

  case "$action" in
    info|nodes|node)    _fm_node_info  ;;
    check|ping)         fm_check "$@"  ;;
    send|push|up)       fm_send  "$@"  ;;
    pull|down|get)      _fm_node_pull "$@" ;;
    sync|mirror)        fm_sync  "$@"  ;;
    mv|move)            _fm_node_mv "$@" ;;
    ls|list)            _fm_node_ls "$@" ;;
    rm|del|delete)      _fm_node_rm "$@" ;;
    exec|run|cmd)       fm_exec  "$@"  ;;
    bkp|backup)
      if declare -f bkp &>/dev/null; then
        bkp "$@"
      else
        cn 208 "fm: bkp() not loaded -- source \$SSOT/functions/backup.sh first"
        return 1
      fi
      ;;
    help|-h|--help)     _fm_help       ;;
    *)
      cn 208 "fm: unknown action '${action}'"
      _fm_help
      return 1
      ;;
  esac
}

_fm_help() {
  cn 226 b "fn / fmx -- Cross-Device File Manager (SSOT)"
  cn 244  "  (fm send|check|sync|exec ... จะ delegate มาที่นี่อัตโนมัติ)"
  echo ""
  cn 75  "  ACTIONS"
  printf "    %-28s %s\n"  "fn info  | fm nodes"          "Show all registered nodes"
  printf "    %-28s %s\n"  "fn check [node|all]"          "Ping/connectivity test"
  printf "    %-28s %s\n"  "fn send  <node> <src> [dst]"  "Push local -> remote"
  printf "    %-28s %s\n"  "fn pull  <node> <src> [dst]"  "Pull remote -> local"
  printf "    %-28s %s\n"  "fn sync  <node> <src> [dst]"  "Mirror local -> remote (--delete)"
  printf "    %-28s %s\n"  "fn mv    <node> <src> <dst>"  "Move local -> remote (rm local)"
  printf "    %-28s %s\n"  "fn ls    <node> [path]"       "List remote directory"
  printf "    %-28s %s\n"  "fn rm    <node> <path>"       "Remove file/dir on remote"
  printf "    %-28s %s\n"  "fn exec  <node> <cmd...>"     "Run command on remote"
  printf "    %-28s %s\n"  "fn bkp   <file...>"           "Local backup (calls bkp)"
  echo ""
  cn 75  "  NODES (auto from bootstrap/nodes/*.node.env)"
  local n
  for n in $(ssot_node_names); do
    ssot_node_resolve "$n" || continue
    printf "    %-26s %s\n" "$n" "${SSOT_NODE_USER}@${SSOT_NODE_HOST}:${SSOT_NODE_PORT}  (${SSOT_NODE_PROTO})"
  done
  printf "    %-26s %s\n" "local | ." "เครื่องนี้"
  echo ""
  cn 245  "  Alias: t|tm termux · w wsl · w2 wsl2 · win|gb window · mm mumu"
  cn 245  "         o oppo · rd redmi · ac acodex · จับ prefix ไม่ซ้ำได้ เช่น gcl = gcloud"
}

# ชื่อสำรองสำหรับเรียก cross-device dispatcher ให้ชัดเจน
fmx() { fn "$@"; }
