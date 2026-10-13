# ============================================================
# Git Toolkit (gt)
# Single-file implementation | Bash 4+
# ============================================================

# ------------------------------------------------------------
# 1. Project Registry
# Compatible with existing path variables
# ------------------------------------------------------------

gt_registry_init() {
    declare -gA GT_PROJECTS=()
    declare -ga GT_PROJECT_ORDER=()

    GT_PROJECT_ORDER=()

    gt_register_project ssot \
        "${SSOT_DIR:-$HOME/ssot}"

    gt_register_project simulator \
        "${DICE_SIM_DIR:-${sim:-$HOME/simulator}}"

    gt_register_project maths-helper \
        "${MATHS_HELPER_DIR:-$HOME/.maths-helper}"

    local config="${GT_CONFIG_FILE:-$HOME/.config/gt/projects.conf}"
    local name path line

    [[ -f "$config" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue

        if [[ "$line" == *"|"* ]]; then
            name="${line%%|*}"
            path="${line#*|}"
        else
            printf 'gt: invalid config line: %s\n' "$line" >&2
            continue
        fi

        # Trim whitespace
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        path="${path#"${path%%[![:space:]]*}"}"
        path="${path%"${path##*[![:space:]]}"}"

        # Allow ~/path without executing shell code
        # NOTE: pattern must be quoted ("~/") — bare ${path#~/}
        # tilde-expands ~/ to $HOME before stripping, so nothing
        # is stripped and you get /home/user/~/ssot.
        if [[ "$path" == "~" ]]; then
            path="$HOME"
        elif [[ "$path" == "~/"* ]]; then
            path="$HOME/${path#"~/"}"
        fi

        # Canonicalize short aliases so config entries using
        # sim/mhp don't create duplicate projects
        case "$name" in
            sim) name="simulator" ;;
            maths|mhp) name="maths-helper" ;;
        esac

        if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ || -z "$path" ]]; then
            printf 'gt: invalid project entry: %s\n' "$line" >&2
            continue
        fi

        gt_register_project "$name" "$path"
    done < "$config"
}

gt_register_project() {
    local name="$1"
    local path="$2"

    if [[ ! ${GT_PROJECTS[$name]+_} ]]; then
        GT_PROJECT_ORDER+=("$name")
    fi

    GT_PROJECTS["$name"]="$path"
}

# ------------------------------------------------------------
# 2. Output helpers
# ------------------------------------------------------------

gt_msg() {
    if declare -F cn >/dev/null 2>&1; then
        cn lg b "$*"
    else
        printf '\n== %s ==\n' "$*"
    fi
}

gt_ok()   { printf '  [OK]   %s\n' "$*"; }
gt_warn() { printf '  [WARN] %s\n' "$*"; }
gt_skip() { printf '  [SKIP] %s\n' "$*"; }
gt_fail() { printf '  [FAIL] %s\n' "$*" >&2; }

gt_usage() {
    cat <<'EOF'
Git Toolkit

Usage:
  gt [command] [project ...] [options]

Commands:
  status    Show working-tree status (default)
  fetch     Fetch remote updates
  pull      Fetch and rebase onto upstream
  commit    Commit staged changes
  push      Push to upstream
  sync      Commit, fetch, rebase, then push
  diff      Show unstaged and staged changes
  log       Show recent commits
  doctor    Health check (read-only, one-line summary per project)
  exec      Run a raw Git command

Projects:
  ssot, simulator, maths-helper, all
  Additional projects: ~/.config/gt/projects.conf

Options:
  -m MESSAGE    Commit message
  --add         Stage all changes before committing
  --dry-run     Preview planned operations
  --network     doctor: also check remote reachability (local-only by default)
  --fix         doctor: apply safe fixes (fetch --prune, set upstream from
                existing remote-tracking ref; never touches working tree)
  -h, --help    Show this help

Examples:
  gt status
  gt status ssot
  gt fetch all
  gt pull ssot
  gt commit ssot --add -m "fix bootstrap"
  gt sync all --add -m "daily update"
  gt diff ssot
  gt doctor
  gt doctor all --network
  gt doctor ssot --fix --dry-run
  gt exec ssot log -5 --oneline

Config format (one project per line):
  docs|/home/user/docs
  app|~/projects/app
EOF
}

# ------------------------------------------------------------
# 3. Project selection
# ------------------------------------------------------------

gt_select_projects() {
    GT_SELECTED=()
    local arg name

    if [[ $# -eq 0 ]]; then
        GT_SELECTED=("${GT_PROJECT_ORDER[@]}")
        return 0
    fi

    for arg in "$@"; do
        if [[ "$arg" == "all" ]]; then
            GT_SELECTED=("${GT_PROJECT_ORDER[@]}")
            return 0
        fi

        name="$arg"
        case "$name" in
            sim) name="simulator" ;;
            maths|mhp) name="maths-helper" ;;
        esac

        if [[ ! ${GT_PROJECTS[$name]+_} ]]; then
            gt_fail "Unknown project: $arg"
            return 2
        fi

        # Avoid duplicate projects
        local found=0 existing
        for existing in "${GT_SELECTED[@]}"; do
            [[ "$existing" == "$name" ]] && found=1 && break
        done

        (( found )) || GT_SELECTED+=("$name")
    done
}

# ------------------------------------------------------------
# 4. Git preflight
# ------------------------------------------------------------

gt_check_repo() {
    local name="$1"
    local dir="${GT_PROJECTS[$name]}"

    if [[ ! -d "$dir" ]]; then
        gt_fail "$name: directory not found: $dir"
        return 1
    fi

    if ! git -C "$dir" rev-parse --is-inside-work-tree \
        >/dev/null 2>&1; then
        gt_fail "$name: not a Git repository"
        return 1
    fi

    local branch
    branch="$(git -C "$dir" symbolic-ref --quiet \
        --short HEAD 2>/dev/null)" || {
        gt_fail "$name: detached HEAD"
        return 1
    }

    printf '%s\n' "$branch"
}

gt_has_upstream() {
    git -C "$1" rev-parse --abbrev-ref \
        --symbolic-full-name '@{u}' >/dev/null 2>&1
}

gt_is_dirty() {
    local dir="$1"

    # Includes tracked and untracked changes.
    [[ -n "$(git -C "$dir" status --porcelain)" ]]
}

gt_has_staged_changes() {
    ! git -C "$1" diff --cached --quiet
}

gt_has_unstaged_changes() {
    ! git -C "$1" diff --quiet
}

gt_has_untracked_files() {
    [[ -n "$(git -C "$1" ls-files \
        --others --exclude-standard)" ]]
}

# ------------------------------------------------------------
# 5. Commit helper
# ------------------------------------------------------------

gt_commit_repo() {
    local name="$1"
    local dir="${GT_PROJECTS[$name]}"
    local message="$GT_MESSAGE"

    if (( GT_ADD )); then
        git -C "$dir" add -A || {
            gt_fail "$name: git add failed"
            return 1
        }
    elif gt_has_unstaged_changes "$dir" ||
         gt_has_untracked_files "$dir"; then
        gt_fail "$name: unstaged or untracked changes; use --add or stage manually"
        return 1
    fi

    if ! gt_has_staged_changes "$dir"; then
        gt_skip "$name: nothing to commit"
        return 0
    fi

    git -C "$dir" commit -m "$message" || {
        gt_fail "$name: commit failed"
        return 1
    }

    gt_ok "$name: committed"
}

# ------------------------------------------------------------
# 6. Safe sync workflow
# ------------------------------------------------------------

gt_sync_repo() {
    local name="$1"
    local dir="${GT_PROJECTS[$name]}"
    local branch

    branch="$(gt_check_repo "$name")" || return 1

    if ! gt_has_upstream "$dir"; then
        gt_fail "$name: no upstream configured"
        return 1
    fi

    # Rebase requires a clean working tree. Commit local changes
    # first, or refuse to proceed if unsafe changes are present.
    if (( GT_DRY_RUN )); then
        gt_msg "DRY RUN: $name ($branch)"
        printf '  Would validate changes, commit if needed, fetch, rebase, push.\n'
        return 0
    fi

    gt_msg "SYNC: $name ($branch)"

    # Step 1: Commit local changes before rebase.
    # This avoids attempting to rebase a dirty working tree.
    gt_commit_repo "$name" || return 1

    # Step 2: Fetch remote state.
    git -C "$dir" fetch || {
        gt_fail "$name: fetch failed"
        return 1
    }

    # Step 3: Check again before changing branch history.
    if gt_is_dirty "$dir"; then
        gt_fail "$name: working tree became dirty after fetch"
        return 1
    fi

    # Step 4: Rebase onto the configured upstream.
    git -C "$dir" rebase '@{u}' || {
        gt_fail "$name: rebase failed; resolve conflicts before continuing"
        return 1
    }

    # Step 5: Push only if all earlier steps succeeded.
    git -C "$dir" push || {
        gt_fail "$name: push failed"
        return 1
    }

    gt_ok "$name: sync complete"
}

# ------------------------------------------------------------
# 6b. Doctor (local health check + safe --fix)
# ------------------------------------------------------------
# Read-only by default. --fix only applies safe operations:
#   - fetch --prune (only with --network)
#   - set upstream to an already-existing remote-tracking ref
# Never touches the working tree (no add/commit/checkout/reset).

gt_doctor_repo() {
    local name="$1"
    local dir="${GT_PROJECTS[$name]}"
    local status="OK"
    local note=""
    local branch="" remote="origin" url=""
    local ahead=0 behind=0
    local staged=0 unstaged=0 untracked=0 stashes=0

    gt_msg "$name"

    # 1. Directory -------------------------------------------------
    if [[ ! -d "$dir" ]]; then
        gt_fail "$name: directory not found: $dir"
        GT_DOCTOR_SUMMARY+=("$name|FAIL|missing dir")
        return 1
    fi

    # 2. Git repository --------------------------------------------
    if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        gt_fail "$name: not a Git repository: $dir"
        GT_DOCTOR_SUMMARY+=("$name|FAIL|not a git repo")
        return 1
    fi

    # 3. Branch ----------------------------------------------------
    if branch="$(git -C "$dir" symbolic-ref --quiet \
            --short HEAD 2>/dev/null)"; then
        gt_ok "branch: $branch"
    else
        gt_fail "detached HEAD"
        status="FAIL"
        note="detached HEAD"
        branch=""
    fi

    # Resolve remote name early (branch config, fallback origin).
    if [[ -n "$branch" ]]; then
        remote="$(git -C "$dir" config \
            "branch.$branch.remote" 2>/dev/null || echo origin)"
    fi
    url="$(git -C "$dir" config "remote.$remote.url" \
        2>/dev/null || true)"

    # 4. Safe fixes that need the network ---------------------------
    if (( GT_FIX )) && (( GT_DOCTOR_NETWORK )) && [[ -n "$url" ]]; then
        if (( GT_DRY_RUN )); then
            printf '  Would fetch --prune %s.\n' "$remote"
        elif git -C "$dir" fetch --prune "$remote" \
                >/dev/null 2>&1; then
            gt_ok "fetched --prune $remote"
        else
            gt_fail "fetch --prune $remote failed"
            status="FAIL"
        fi
    fi

    # 5. Upstream ---------------------------------------------------
    if gt_has_upstream "$dir"; then
        gt_ok "upstream: $(git -C "$dir" rev-parse --abbrev-ref \
            --symbolic-full-name '@{u}' 2>/dev/null)"
    else
        if (( GT_FIX )) && [[ -n "$branch" ]] && \
            git -C "$dir" rev-parse --verify --quiet \
                "refs/remotes/$remote/$branch" >/dev/null 2>&1; then
            if (( GT_DRY_RUN )); then
                printf '  Would set upstream to %s/%s.\n' \
                    "$remote" "$branch"
                gt_warn "no upstream configured ($remote/$branch exists)"
            elif git -C "$dir" branch \
                    --set-upstream-to="$remote/$branch" "$branch" \
                    >/dev/null 2>&1; then
                gt_ok "upstream set to $remote/$branch"
            else
                gt_fail "could not set upstream to $remote/$branch"
                status="FAIL"
            fi
        else
            gt_warn "no upstream configured"
            [[ "$status" != "FAIL" ]] && status="WARN"
        fi
    fi

    # 6. Remote reachability (opt-in) --------------------------------
    if (( GT_DOCTOR_NETWORK )); then
        if [[ -z "$url" ]]; then
            gt_warn "no URL for remote '$remote'; skipping reachability check"
            [[ "$status" == "OK" ]] && status="WARN"
        else
            local -a _probe=(git -C "$dir" ls-remote \
                --exit-code "$remote" HEAD)
            if command -v timeout >/dev/null 2>&1; then
                _probe=(timeout 10 "${_probe[@]}")
            fi
            if "${_probe[@]}" >/dev/null 2>&1; then
                gt_ok "remote reachable: $remote"
            else
                gt_fail "remote unreachable: $remote ($url)"
                status="FAIL"
            fi
        fi
    else
        gt_skip "remote check skipped (use --network)"
    fi

    # 7. Ahead / behind ----------------------------------------------
    if gt_has_upstream "$dir"; then
        if read -r ahead behind < <(git -C "$dir" rev-list \
                --left-right --count 'HEAD...@{u}' 2>/dev/null); then
            if (( ahead == 0 && behind == 0 )); then
                gt_ok "up-to-date with upstream"
            else
                gt_warn "ahead $ahead, behind $behind"
                [[ "$status" == "OK" ]] && status="WARN"
            fi
        fi
    fi

    # 8. Working tree -------------------------------------------------
    staged="$(git -C "$dir" diff --cached --numstat 2>/dev/null \
        | wc -l)"
    unstaged="$(git -C "$dir" diff --numstat 2>/dev/null | wc -l)"
    untracked="$(git -C "$dir" ls-files --others --exclude-standard \
        2>/dev/null | wc -l)"
    if (( staged == 0 && unstaged == 0 && untracked == 0 )); then
        gt_ok "working tree clean"
    else
        gt_warn "dirty: $staged staged, $unstaged unstaged, $untracked untracked"
        [[ "$status" == "OK" ]] && status="WARN"
    fi

    # 9. Stash ----------------------------------------------------------
    stashes="$(git -C "$dir" stash list 2>/dev/null | wc -l)"
    if (( stashes > 0 )); then
        gt_warn "$stashes stash entr$( (( stashes == 1 )) \
            && echo 'y' || echo 'ies') kept"
        [[ "$status" == "OK" ]] && status="WARN"
    else
        gt_ok "no stashes"
    fi

    # 10. Merge / rebase in progress --------------------------------------
    local _gitdir
    _gitdir="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)"
    if [[ -n "$_gitdir" ]] && [[ -e "$_gitdir/MERGE_HEAD" || \
            -d "$_gitdir/rebase-merge" || -d "$_gitdir/rebase-apply" || \
            -e "$_gitdir/CHERRY_PICK_HEAD" ]]; then
        gt_fail "merge/rebase/cherry-pick in progress; resolve before sync"
        status="FAIL"
    else
        gt_ok "no merge/rebase in progress"
    fi

    # 11. Identity ----------------------------------------------------------
    if [[ -z "$(git -C "$dir" config user.name 2>/dev/null)" || \
          -z "$(git -C "$dir" config user.email 2>/dev/null)" ]]; then
        gt_warn "user.name/user.email not set (commit will fail)"
        [[ "$status" == "OK" ]] && status="WARN"
    else
        gt_ok "identity: $(git -C "$dir" config user.name) <$(git -C "$dir" \
            config user.email)>"
    fi

    # 12. Remote URL -----------------------------------------------------------
    if [[ -z "$url" ]]; then
        gt_warn "no remote URL configured"
        [[ "$status" == "OK" ]] && status="WARN"
    else
        gt_ok "remote: $url"
    fi

    # Summary note ---------------------------------------------------------------
    if [[ -z "$note" ]]; then
        if [[ "$status" == "OK" ]]; then
            note="clean"
            if (( ahead == 0 && behind == 0 )) && gt_has_upstream "$dir"; then
                note="clean, up-to-date"
            fi
        else
            note="see $status lines above"
        fi
    fi
    GT_DOCTOR_SUMMARY+=("$name|$status|$note")
    [[ "$status" == "OK" ]]
}

# ------------------------------------------------------------
# 7. Command dispatcher
# ------------------------------------------------------------

gt() {
    local cmd="status"
    local message_set=0
    local -a projects=()
    local -a raw_args=()

    GT_MESSAGE="update"
    GT_ADD=0
    GT_DRY_RUN=0
    GT_DOCTOR_NETWORK=0
    GT_FIX=0

    # First argument may be a command (help flags are parsed
    # in the loop below so `gt --help` / `gt -h` work).
    if [[ $# -gt 0 ]]; then
        case "$1" in
            status|fetch|pull|commit|push|sync|diff|log|doctor|exec)
                cmd="$1"
                shift
                ;;
        esac
    fi

    # Parse project names and toolkit options.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                gt_usage
                return 0
                ;;
            -m)
                if [[ -z "${2:-}" ]]; then
                    gt_fail "-m requires a commit message"
                    return 2
                fi
                GT_MESSAGE="$2"
                message_set=1
                shift 2
                ;;
            --add)
                GT_ADD=1
                shift
                ;;
            --dry-run)
                GT_DRY_RUN=1
                shift
                ;;
            --network)
                GT_DOCTOR_NETWORK=1
                shift
                ;;
            --fix)
                GT_FIX=1
                shift
                ;;
            --)
                shift
                raw_args+=("$@")
                break
                ;;
            *)
                if [[ "$cmd" == "exec" ]]; then
                    # First non-option arg is the project,
                    # everything after it is a raw git argument
                    # (even flags like -m/--add must not be parsed).
                    projects+=("$1")
                    shift
                    raw_args+=("$@")
                    break
                fi
                projects+=("$1")
                shift
                ;;
        esac
    done

    gt_registry_init || return 1

    if [[ "$cmd" == "exec" ]]; then
        if [[ ${#projects[@]} -ne 1 || ${#raw_args[@]} -eq 0 ]]; then
            gt_fail "Usage: gt exec PROJECT git-arguments..."
            return 2
        fi
        local project="${projects[0]}"
        [[ "$project" == "all" ]] && {
            gt_fail "exec requires exactly one project"
            return 2
        }
        case "$project" in
            sim) project="simulator" ;;
            maths|mhp) project="maths-helper" ;;
        esac
        [[ ${GT_PROJECTS[$project]+_} ]] || {
            gt_fail "Unknown project: $project"
            return 2
        }
        git -C "${GT_PROJECTS[$project]}" "${raw_args[@]}"
        return $?
    fi

    gt_select_projects "${projects[@]}" || return $?

    if [[ "$cmd" == "doctor" ]]; then
        GT_DOCTOR_SUMMARY=()
        local drc=0 row sname sstat snote srest
        local dname

        for dname in "${GT_SELECTED[@]}"; do
            gt_doctor_repo "$dname" || drc=1
            printf '\n'
        done

        printf 'Summary:\n'
        for row in "${GT_DOCTOR_SUMMARY[@]}"; do
            sname="${row%%|*}"
            srest="${row#*|}"
            sstat="${srest%%|*}"
            snote="${srest#*|}"
            printf '  %-14s %-7s %s\n' "$sname" "$sstat" "$snote"
        done

        return "$drc"
    fi

    if [[ "$cmd" == "commit" && "$message_set" -eq 0 ]]; then
        GT_MESSAGE="update"
    fi

    local name dir branch rc=0

    for name in "${GT_SELECTED[@]}"; do
        dir="${GT_PROJECTS[$name]}"

        branch="$(gt_check_repo "$name")" || {
            rc=1
            continue
        }

        case "$cmd" in
            status)
                gt_msg "$name ($branch)"
                git -C "$dir" status -sb || rc=1
                ;;
            fetch)
                gt_msg "FETCH: $name ($branch)"
                if (( GT_DRY_RUN )); then
                    printf '  Would fetch remote updates.\n'
                else
                    git -C "$dir" fetch || rc=1
                fi
                ;;
            pull)
                gt_msg "PULL: $name ($branch)"
                if gt_is_dirty "$dir"; then
                    gt_fail "$name: working tree is dirty"
                    rc=1
                elif ! gt_has_upstream "$dir"; then
                    gt_fail "$name: no upstream configured"
                    rc=1
                elif (( GT_DRY_RUN )); then
                    printf '  Would fetch and rebase onto upstream.\n'
                elif git -C "$dir" fetch &&
                     git -C "$dir" rebase '@{u}'; then
                    gt_ok "$name: pull complete"
                else
                    gt_fail "$name: pull failed; inspect repository state"
                    rc=1
                fi
                ;;
            commit)
                if (( GT_DRY_RUN )); then
                    gt_msg "DRY RUN: COMMIT $name"
                    printf '  Would commit staged changes%s.\n' \
                        "$([[ $GT_ADD -eq 1 ]] && printf ' after git add -A')"
                else
                    gt_commit_repo "$name" || rc=1
                fi
                ;;
            push)
                gt_msg "PUSH: $name ($branch)"
                if ! gt_has_upstream "$dir"; then
                    gt_fail "$name: no upstream configured"
                    rc=1
                elif (( GT_DRY_RUN )); then
                    printf '  Would push to upstream.\n'
                elif git -C "$dir" push; then
                    gt_ok "$name: push complete"
                else
                    gt_fail "$name: push failed"
                    rc=1
                fi
                ;;
            sync)
                gt_sync_repo "$name" || rc=1
                ;;
            diff)
                gt_msg "DIFF: $name ($branch)"
                git -C "$dir" diff &&
                    git -C "$dir" diff --cached || rc=1
                ;;
            log)
                gt_msg "LOG: $name ($branch)"
                git -C "$dir" log -10 --oneline --decorate || rc=1
                ;;
        esac
        printf '\n'
    done

    return "$rc"
}

