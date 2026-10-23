#!/bin/bash
# ============================================================
# 🚀 JOE'S PERSONAL COMMAND CENTER — Main Entry Point
# ============================================================
# Works on WSL, Termux (incl. MuMu), and Git Bash via single source.
# Detection order: Termux → WSL → Git Bash → MUMU
# ============================================================
# -- first of everything make sure you have yet to source main helper
if ! declare -f _check &> /dev/null; then
    [[ -f "$HOME/ssot/.bash_helper" ]] && source "$HOME/ssot/.bash_helper"
fi
# ── Step 0: JOE_ENV detection (fallback — ปกติ set จาก ~/.env หรือ .bashrc) ──
# ค่าที่ใช้ได้: TERMUX | WSL | GIT-BASH | MUMU

export JOE_ENV=$(_check_ -j 2>/dev/null)


#--- Global constants (machine-independent)



# ── Step 2: Set derived paths based on JOE_ENV ──
# SSOT: respect existing value (set by repo() or ~/.env), only set default if empty
if [[ -z "${SSOT:-}" ]]; then
    case "$JOE_ENV" in
        TERMUX)
            export SSOT="/data/data/com.termux/files/home/ssot"
            ;;
        MUMU)
            export SSOT="/data/data/com.termux/files/home/ssot"
            ;;
				OPPO)
            export SSOT="/data/data/com.termux/files/home/ssot"
            ;;
				ACODEX)
            export SSOT="$HOME/ssot"
            ;;		
        WSL)
            export SSOT="$HOME/ssot"
            ;;
        GIT-BASH)
            export SSOT="$HOME/ssot"
            ;;
        *)
            export SSOT="$HOME/ssot"
            ;;
    esac
fi

# -- Derived paths & global vars are now in shared/00-env.sh (SSOT) --
# Loaded via ssot_load() below. Nothing to set here.




# ── Step 1.5: CRLF SELF-HEAL (กันไฟล์ CRLF ทำ bash พัง) ──
# Syncthing sync ข้ามเครื่อง (WSL ↔ Termux/Acode-X ↔ Win ↔ MuMu)
# ถ้าเครื่องไหนแก้ไฟล์แล้วบันทึกเป็น CRLF (Windows/Acode-X) bash จะ
# syntax error ทันที — ตรงนี้แปลงกลับเป็น LF ให้อัตโนมัติก่อน source
# หมายเหตุ: ถ้า joe.sh ตัวเองเป็น CRLF จะ parse ไม่ผ่านมาถึงตรงนี้
# → ต้องมี guard ใน .bashrc ด้วย (ดู .bashrc section 6)
crlf(){

 if [[ "$JOE_ENV" != "GIT-BASH" ]] && command -v grep >/dev/null 2>&1 && command -v sed >/dev/null 2>&1; then
    _crlf_files="$(grep -rlU $'\r' "$SSOT" --include="*.sh" 2>/dev/null)"
    if [[ -n "$_crlf_files" ]]; then
        _crlf_count=0
        while IFS= read -r _f; do
            sed -i 's/\r$//' "$_f"
            _crlf_count=$((_crlf_count+1))
        done <<< "$_crlf_files"
        # Send to STDERR (not STDOUT) so Powerlevel10k instant prompt
        # is not disturbed — p10k flags ANY stdout during init as a
        # problem and prints a multi-line warning to the user.
        echo "⚠️  CRLF auto-fixed: ${_crlf_count} file(s) → LF (มาจากเครื่องอื่น/Windows)" >&2
    fi
 fi
}

# ── Auto start sshd & ssh-agent ──


# Auto-start sshd if not running (guarded for git-bash which lacks pgrep)
# Auto-start ssh-agent if not running (needed for tm/tw key auth)
# Auto-start ssh-agent if not running (needed for tm/tw key auth)

auto_start_ssh(){
  # Auto-start sshd guarded by JOE_ENV
 if [[ "$JOE_ENV" == "WSL" || "$JOE_ENV" == "WSL2" ]]; then
    # WSL: ใช้ service ssh
    if ! service ssh status >/dev/null 2>&1; then
        sudo service ssh start >/dev/null 2>&1 && { command -v cn &>/dev/null && cn 10 b "SSH Service (WSL) started successfully." >&2; } || { command -v cn &>/dev/null && cn 9 b "Failed to start SSH Service." >&2; }
    else
        command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
    fi
 elif [[ "$JOE_ENV" == @(TERMUX|MUMU|OPPO) ]]; then
    # Termux / MuMu: ใช้ sshd binary ตรงๆ
    # NOTE: Termux ใหม่ rename process เป็น "sshd-session" ไม่ใช่ "sshd"
    # → pgrep -x sshd ใช้ไม่ได้ ต้อง check จาก port ที่ bind อยู่จริงแทน
    if ! pgrep -f "sshd.*-p.*${SSH_PORT}" >/dev/null 2>&1; then
        sshd -p "$SSH_PORT" >/dev/null 2>&1 && { command -v cn &>/dev/null && cn 10 b "SSH Daemon started on port ${SSH_PORT}." >&2; } || { command -v cn &>/dev/null && cn 9 b "Failed to start sshd on port ${SSH_PORT}." >&2; }
    else
        command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" >&2
    fi
	else
		if ! pgrep -f "sshd.*-p.*${SSH_PORT}" >/dev/null 2>&1; then
        /usr/sbin/sshd -p "$SSH_PORT" && { command -v cn &>/dev/null && cn 10 b "SSH Daemon started on port ${SSH_PORT}." >&2; } || { command -v cn &>/dev/null && cn 9 b "Failed to start sshd on port ${SSH_PORT}." ; }
    else
        command -v cn &>/dev/null && cn 10 bi "ssh activated port : ${SSH_PORT}" #>&2	
		fi		
 fi
}



ssot_load(){
    # -- Load all scripts in SSOT folders with priority order --
    if ! typeset -f _check &>/dev/null; then
        if [ -f "$SSOT/shared/.bash_helper" ]; then
            source "$SSOT/shared/.bash_helper"
        elif [ -f "$SSOT/.bash_helper" ]; then
            source "$SSOT/.bash_helper"
        fi
    fi

    local SHOW_LOAD="${1:-""}"
    local source_files=(
        "$SSOT/shared/00-env.sh"
        "$SSOT/core/gt.sh"
        "$SSOT/core/ssh_toolkit.sh"
        "$SSOT/core/3worlds.sh"
				"$SSOT/core/ssh-toolkit.sh"
        "$SSOT/shared/aliases.sh"
        "$SSOT/core/profiles.sh"
       	"$SSOT/core/lazy-load_engine.sh"
				"$SSOT/plugins/joe_theme/plugin.sh"
    )

    # 1. shared/functions (priority core tools & loader)
    if [[ -d "$SSOT/shared/functions" ]]; then
        local _f_sh=""
        while IFS= read -r _f_sh; do
            [[ -f "$_f_sh" ]] && source_files+=("$_f_sh")
        done < <(find "$SSOT/shared/functions" -type f -name "*.sh" ! -name ".*" | LC_ALL=C sort)
    fi

    # 2. shared/personal (personal helper functions)
    if [[ -d "$SSOT/shared/personal" ]]; then
        local _p_sh=""
        while IFS= read -r _p_sh; do
            [[ -f "$_p_sh" ]] && source_files+=("$_p_sh")
        done < <(find "$SSOT/shared/personal" -type f -name "*.sh" ! -name ".*" | LC_ALL=C sort)
    fi

    # 3. Dynamic loader: Any additional subdirectories or nested folders inside shared/
    if [[ -d "$SSOT/shared" ]]; then
        local _extra_sh=""
        while IFS= read -r _extra_sh; do
            [[ -f "$_extra_sh" ]] && source_files+=("$_extra_sh")
        done < <(find "$SSOT/shared" -mindepth 2 -type f -name "*.sh" \
            ! -path "$SSOT/shared/functions/*" \
            ! -path "$SSOT/shared/personal/*" \
            ! -name ".*" | LC_ALL=C sort)
    fi

    #-- run main cmd
    _check -f "source_files" "source" 2>/dev/null
    #-- เรียกดูไฟล์ท่ถูก source ตามลำดับ
    if [[ -n "${SHOW_LOAD}" && "${SHOW_LOAD}" =~ ^(true|1|yes)$ ]]; then
        local basen_files=() 
        local max_len=0 
        local sf=""

        for sf in "${source_files[@]}"; do
            if [[ -f "$sf" ]]; then
                local f_name=""
                f_name="${sf##*/}"            
                basen_files+=("$f_name")
            fi
        done
        # -- Calculate max length --
        local file_name=""
        local len=0
        local padding=0

        for file_name in "${basen_files[@]}"; do
            len=${#file_name}
            if (( len > max_len )); then
                max_len=$len
            fi
        done
        # -- Print with alignment --
        for file_name in "${basen_files[@]}"; do
            padding=$((max_len - ${#file_name} + 5))
            printf "%s   %s%*s %s\n" \
                "$(c 202 b "source")" \
                "$(c 246 b "$file_name")" \
                "${padding}" "" \
                "$(c 46 b "done")"
        done        
    fi
}

#-- Global shell refresh
refresh_shell() {

    while (( $# > 0 )); do
        case $1 in
            -p|--profile) 
                LOAD_LIST="${2:-""}"  
                shift 2 
                ;;
            -l|--load) 
                LOAD_LIST="${2:-""}" 
                shift 2 
                ;;
            -q|--quick)
                 _C --shell -d "source $HOME/.zshrc" "source $HOME/.bashrc"
                # -- no clear screen
                return 
                ;;
            -e|--exec)
                 _C --shell -d "exec zsh" "exec 'bash'"
                return 
                ;;
            *) 
                LOAD_LIST="${1:-""}" 
                shift 1 
                ;;
        esac       
    done
    
    clear
    
    _C -s -d "[[ -f $HOME/.zshrc ]] && source $HOME/.zshrc " "[[ -f $HOME/.bashrc ]] && source $HOME/.bashrc"
    
    #cn 46 b "✓ Config reloaded!"
}
alias pp="refresh_shell"
alias qpp='refresh_shell -q'
alias epp='refresh_shell -e'


# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
#                      START UP                      #
# ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ #
# m a 50  # offset=50 cols from left (was 0=full-center, looked like 'hang' on slow shells)

# Init-time startup tasks — wrapped in { ... } >&2 so any console
# output from syncthing_auto / rc_del goes to STDERR only.
# Required by Powerlevel10k instant prompt (sourced first in .zshrc):
# p10k is strict — ANY stdout during zsh init invalidates the
# instant prompt and prints a multi-line warning to the user.
ssot_load ${LOAD_LIST:-}
 {
    unbinding -a g    
    
    pf ${AI_PROFILE:-mom}
   	  case "$JOE_ENV" in 
        TERMUX|MUMU|OPPO) rc_delete ;;
  	  esac
    unset LOAD_LIST
    unset AI_PROFILE
	auto_start_ssh
    crlf

 } >/dev/null 2>&1

# เช็คว่า JOE_ENV ไม่ใช่ WSL, OPPO หรือ MUMU
if [[ "$JOE_ENV" == @(OPPOZ) ]]; then

    # 1. เช็คก่อนว่ามีคำสั่ง pgrep ในระบบไหม
    if ! command -v pgrep >/dev/null 2>&1; then
        cn 9 b "pgrep not found, skipping syncthing check"

    # 2. ถ้ามี pgrep ให้เช็คว่า syncthing รันอยู่ไหม
    elif ! pgrep -f syncthing >/dev/null 2>&1; then
        cn 202 b "syncthing not running, starting..."
        ( syncthing_auto >/dev/null 2>&1 & )

    # 3. ถ้ารันอยู่แล้ว
    else
        cn 202 b "Syncthing is already running"
    fi

fi






# Disable nounset after everything is loaded — ble.sh restores set -u
# after each command, but joe.sh uses unset variables (dbp, $2, etc.)
set +u

