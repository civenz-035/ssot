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
        [[ "$path" == "~/"* ]] && path="$HOME/${path#~/}"

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
  exec      Run a raw Git command

Projects:
  ssot, simulator, maths-helper, all
  Additional projects: ~/.config/gt/projects.conf

Options:
  -m MESSAGE    Commit message
  --add         Stage all changes before committing
  --dry-run     Preview planned operations
  -h, --help    Show this help

Examples:
  gt status
  gt status ssot
  gt fetch all
  gt pull ssot
  gt commit ssot --add -m "fix bootstrap"
  gt sync all --add -m "daily update"
  gt diff ssot
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

    # First argument may be a command or an option.
    if [[ $# -gt 0 ]]; then
        case "$1" in
            status|fetch|pull|commit|push|sync|diff|log|exec|-h|--help)
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
            --)
                shift
                raw_args+=("$@")
                break
                ;;
            *)
                if [[ "$cmd" == "exec" ]]; then
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
        [[ ${GT_PROJECTS[$project]+_} ]] || {
            gt_fail "Unknown project: $project"
            return 2
        }
        git -C "${GT_PROJECTS[$project]}" "${raw_args[@]}"
        return $?
    fi

    gt_select_projects "${projects[@]}" || return $?

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