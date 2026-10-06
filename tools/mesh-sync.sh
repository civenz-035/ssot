#!/usr/bin/env bash
# ============================================================
# tools/mesh-sync.sh — Git sync for ~/ssot across all mesh nodes
#
#   mesh-sync status              # show every node's state
#   mesh-sync push                # commit + push this node to origin
#   mesh-sync pull                # fetch + rebase this node from origin
#   mesh-sync sync                # pull, then push (safe order)
#   mesh-sync pull-node <node>    # run git pull on another node over SSH
#   mesh-sync push-node <node>    # run git push  on another node over SSH
#   mesh-sync fanpull             # pull on every reachable node
#   mesh-sync fanpush             # push  on every reachable node
#   mesh-sync broadcast           # pull everywhere, then push everywhere
#
# Design notes
# ------------
# · Every node is an independent checkout of the SAME repo with the SAME
#   remote, so a plain `git push` on a node can be rejected or can land on
#   top of another node's work. fanpull runs BEFORE fanpush for that reason.
# · Never uses `git push --force`. A rejected push means someone else pushed
#   first; the correct response is to pull, not to overwrite their commits.
# · Never runs `git clean -fdx`; these checkouts carry Syncthing state and
#   editor files that must survive.
# · Nodes that are offline are reported, never silently skipped.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"

# ── Colors ──
# Prefer the SSOT helpers. tools/ is not auto-loaded, so this script may run
# standalone; the fallback builds the escape with %b so no raw ANSI literal
# appears in this file.
_colors_file="$REPO_ROOT/core/01-colors.sh"
if [[ -f "$_colors_file" ]]; then
    source "$_colors_file" 2>/dev/null
fi
if ! declare -F c >/dev/null 2>&1; then
    _ESC=$'\033'
    c() {  # c <256> <style> <text...>
        local code="$1" style="$2"; shift 2
        local b="" d=""
        [[ "$style" == "b" ]] && b="1;"
        [[ "$style" == "d" ]] && d="2;"
        printf '%b[%s38;5;%sm%s%b[0m' "$_ESC" "$b" "$code" "$*" "$_ESC"
    }
fi
_ok()   { c 82 b  "  ✅ $*"; }
_warn() { c 214 b "  ⚠️  $*"; }
_err()  { c 203 b "  ❌ $*"; }
_info() { c 245 d "  $*"; }
_hdr()  { c 136 b "── $* ─────────────────────────────"; }

# ── Node registry ──
load_nodes() {
    local loader="$REPO_ROOT/bootstrap/nodes/loader.sh"
    if [[ -f "$loader" ]]; then
        source "$loader" 2>/dev/null
    fi
    if [[ -z "${SSOT_REGISTERED_NODES:-}" ]]; then
        _err "no node registry found at $REPO_ROOT/bootstrap/nodes/"
        return 1
    fi
    return 0
}

node_var() {  # node_var <node> <suffix>  e.g. node_var wsl HOST
    local name; name="$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"
    local v=""
    # node.env files are free to abbreviate the prefix — window.node.env uses
    # NODE_WIN_* while its node name is "window". Try the literal name first,
    # then the common abbreviations.
    local cand_names=("$name")
    case "$name" in
        WINDOW) cand_names=("WIN" "WINDOW") ;;
        WSL2)   cand_names=("WSL2" "WSL_2") ;;
        TERMUX) cand_names=("TERMUX" "TM") ;;
        MUMU)   cand_names=("MUMU" "MM") ;;
        ACODEX) cand_names=("ACODEX" "A") ;;
    esac
    local cn
    for cn in "${cand_names[@]}"; do
        v="$(eval "printf '%s' \"\${NODE_${cn}_${2}:-}\"")"
        [[ -n "$v" ]] && break
    done
    # Syncthing can inject CRLF into node.env files; a port of "2223\r" makes
    # ssh fail with "Bad port", so strip it wherever we read a value.
    v="${v//$'\r'/}"; v="${v//$'\n'/}"
    printf '%s' "$v"
}

# ── SSH reachability with a short timeout ──
node_reachable() {  # node_reachable <node>
    local n="$1" host user port
    host="$(node_var "$n" HOST)"; user="$(node_var "$n" USER)"; port="$(node_var "$n" PORT)"
    if [[ -z "$host" || -z "$user" || -z "$port" ]]; then
        _info "incomplete node profile (missing HOST/USER/PORT in $n.node.env)"
        return 2
    fi

    local opts=(-o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new)
    [[ -f "${HOME}/.ssh/id_ed25519_node" ]] && opts+=(-i "${HOME}/.ssh/id_ed25519_node")

    ssh "${opts[@]}" -p "$port" "$user@$host" 'true' >/dev/null 2>&1
}

node_ssh() {  # node_ssh <node> <cmd...>
    local n="$1"; shift
    local host user port
    host="$(node_var "$n" HOST)"; user="$(node_var "$n" USER)"; port="$(node_var "$n" PORT)"
    port="${port//$'\r'/}"; port="${port//$'\n'/}"
    local opts=(-o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new)
    [[ -f "${HOME}/.ssh/id_ed25519_node" ]] && opts+=(-i "${HOME}/.ssh/id_ed25519_node")
    ssh "${opts[@]}" -p "$port" "$user@$host" "$@"
}

# Git command run on a remote node, inside its own ~/ssot.
#
# The command is delivered over stdin rather than as an argument: `ssh host
# bash -s -- args` does not forward args to a script read from stdin, and
# `bash -c "cd x; git ..."` makes ssh concatenate the pieces into one string,
# so `git` ends up as a bare word. A heredoc is the shape that works.
#
# SSOT may live under a different HOME on Android (Termux resolves HOME to the
# app data dir), so probe a couple of candidates instead of assuming ~/ssot.
remote_git() {  # remote_git <node> <subcommand...>
    local n="$1"; shift
    local subcmd="$*"
    node_ssh "$n" bash -s <<EOF
d="\${SSOT:-\$HOME/ssot}"
for cand in "\$d" /data/data/com.termux/files/home/ssot "\$HOME/ssot"; do
    if [ -d "\$cand/.git" ]; then d="\$cand"; break; fi
done
if [ ! -d "\$d/.git" ]; then echo "NO_REPO"; exit 3; fi
cd "\$d" || exit 3
git $subcmd
EOF
}

# ── Local git operations ──
in_repo() {
    if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        _err "not a git repo: $REPO_ROOT"
        return 1
    fi
    return 0
}

local_push() {
    in_repo || return 1
    local dirty
    dirty="$(git -C "$REPO_ROOT" status --porcelain)"
    if [[ -n "$dirty" ]]; then
        _warn "working tree has uncommitted changes:"
        printf '%s\n' "$dirty" | head -10 | while IFS= read -r l; do _info "$l"; done
        _info "commit them first (git add -A && git commit -m '...')"
    fi
    git -C "$REPO_ROOT" fetch origin --quiet 2>&1
    local behind ahead
    behind="$(git -C "$REPO_ROOT" rev-list --count HEAD..origin/$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD) 2>/dev/null || echo '?')"
    ahead="$(git -C "$REPO_ROOT" rev-list --count origin/$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null || echo '?')"
    _info "ahead of origin: $ahead commit(s) | behind: $behind"
    if git -C "$REPO_ROOT" push origin HEAD 2>&1; then
        _ok "pushed to origin ($(git -C "$REPO_ROOT" rev-parse --short HEAD))"
        return 0
    else
        _err "push rejected — another node pushed first. Run: mesh-sync pull"
        return 1
    fi
}

local_pull() {
    in_repo || return 1
    local branch; branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    git -C "$REPO_ROOT" fetch origin --quiet 2>&1
    # Rebase keeps the local history linear, which matters when several nodes
    # commit into the same branch. A dirty tree cannot be rebased.
    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
        _err "working tree dirty — commit or stash before pulling"
        return 1
    fi
    if git -C "$REPO_ROOT" rev-list --count HEAD..origin/"$branch" 2>/dev/null | grep -q '^0$'; then
        _ok "already up to date with origin/$branch"
        return 0
    fi
    if git -C "$REPO_ROOT" pull --rebase origin "$branch" 2>&1; then
        _ok "rebased onto origin/$branch ($(git -C "$REPO_ROOT" rev-parse --short HEAD))"
        return 0
    else
        _err "rebase hit a conflict. Resolve manually:"
        _info "  git -C $REPO_ROOT status"
        _info "  git -C $REPO_ROOT rebase --continue   (or --abort)"
        return 1
    fi
}

# ── Fan-out operations ──
fan() {  # fan <verb> [args...]   verb = pull|push
    load_nodes || return 1
    local verb="$1"; shift
    local reachable=() offline=()

    printf '\n'
    _hdr "Scanning nodes"
    for n in "${SSOT_REGISTERED_NODES[@]}"; do
        printf "  %-10s " "$n"
        node_reachable "$n"
        case $? in
            0) c 82 b "online";  reachable+=("$n") ;;
            2) c 196 b "bad profile"; offline+=("$n") ;;
            *) c 245 d "offline";  offline+=("$n") ;;
        esac
    done

    printf '\n'
    _hdr "Running: $verb"
    if [[ ${#reachable[@]} -eq 0 ]]; then
        _warn "no reachable nodes"
        return 1
    fi

    local failures=0
    for n in "${reachable[@]}"; do
        printf '\n'
        c 141 b "  [$n] $verb"
        local out rc
        out="$(remote_git "$n" "$@" 2>&1)"; rc=$?
        [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/    /'
        if [[ $rc -ne 0 ]]; then
            _warn "$n: failed"
            # Name the actual cause — a bare "failed" makes a dirty working
            # tree and a revoked GitHub key look identical.
            case "$out" in
                *NO_REPO*)                     _info "  cause: no ssot checkout on that node" ;;
                *"unstaged changes"*|*"uncommitted"*)
                                               _info "  cause: dirty working tree — commit or stash on $n first" ;;
                *suspended*|*"403"*)          _info "  cause: GitHub rejected the credentials (account suspended?)" ;;
                *Permission*denied*publickey*|*"Could not read from remote"*)
                                               _info "  cause: no working SSH key on $n for the remote" ;;
                *"Could not resolve"*|*"Connection refused"*|*"timed out"*)
                                               _info "  cause: node went offline mid-run" ;;
                *"conflict"*)                  _info "  cause: rebase conflict — resolve on $n manually" ;;
                *)                             _info "  cause: see output above" ;;
            esac
            failures=$((failures+1))
        fi
    done

    printf '\n'
    if [[ ${#offline[@]} -gt 0 ]]; then
        _info "skipped (not reachable): ${offline[*]}"
    fi
    if [[ $failures -eq 0 ]]; then
        _ok "$verb completed on ${#reachable[@]} node(s)"
        return 0
    else
        _err "$failures operation(s) failed"
        return 1
    fi
}

show_status() {
    load_nodes || return 1
    printf '\n'
    c 141 b "🎲 mesh-sync — SSOT sync status"
    _hdr "this node"
    if in_repo; then
        local branch; branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
        _info "repo   : $REPO_ROOT"
        _info "branch : $branch  @ $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
        local dirty; dirty="$(git -C "$REPO_ROOT" status --porcelain | wc -l)"
        [[ "$dirty" -gt 0 ]] && _warn "$dirty uncommitted change(s)" || _ok "tree clean"
    fi

    _hdr "nodes"
    for n in "${SSOT_REGISTERED_NODES[@]}"; do
        printf '  %-10s ' "$n"
        if node_reachable "$n"; then
            local head dirty
            head="$(remote_git "$n" 'rev-parse --short HEAD' 2>/dev/null | tr -d '\r' | tail -1)"
            dirty="$(remote_git "$n" 'status --porcelain | wc -l' 2>/dev/null | tr -d '\r' | tail -1)"
            if [[ -n "$head" ]]; then
                if [[ "${dirty:-0}" -gt 0 ]]; then
                    c 214 b "online @ $head (${dirty} uncommitted)"
                else
                    c 82 b "online @ $head (clean)"
                fi
            else
                c 196 b "online, no repo"
            fi
        else
            case $? in
                2) c 196 b "bad node profile" ;;
                *) c 245 d "offline" ;;
            esac
        fi
    done
    printf '\n'
}

usage() {
    sed -n '2,/^set -/p' "$0" \
        | sed 's/^#\{1,\} \{0,1\}//' \
        | sed '/^$/d;/^set -/d;/^=\{4,\}$/d'
}

# ── Dispatch ──
cmd="${1:-status}"; shift || true
case "$cmd" in
    status)            show_status ;;
    push)              local_push ;;
    pull)              local_pull ;;
    sync)              local_pull && local_push ;;
    pull-node)         [[ -n "${1:-}" ]] || { _err "usage: mesh-sync pull-node <node>"; exit 2; }
                       load_nodes && printf '\n' && c 141 b "  [$1] pull" && remote_git "$1" 'pull --rebase' ;;
    push-node)         [[ -n "${1:-}" ]] || { _err "usage: mesh-sync push-node <node>"; exit 2; }
                       load_nodes && printf '\n' && c 141 b "  [$1] push" && remote_git "$1" 'push origin HEAD' ;;
    fanpull)           fan pull pull --rebase ;;
    fanpush)           fan push push origin HEAD ;;
    broadcast)         # pull everywhere first, then push, so a node cannot
                       # push on top of commits it has not seen yet
                       local_pull && fan pull pull --rebase && fan push push origin HEAD ;;
    -h|--help|help)    usage ;;
    *)                 _err "unknown command: $cmd"; echo; usage; exit 2 ;;
esac