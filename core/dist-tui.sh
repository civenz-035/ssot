#!/usr/bin/env bash
# disk-tui.sh — Linux / Bash / GNU coreutils + findutils
# Default: dry-run. No automatic deletion of source directories.

set -u
set -o pipefail
umask 077

if (( EUID == 0 )); then
    printf 'กรุณารันด้วยบัญชีผู้ใช้ปกติ ไม่ใช้ sudo\n' >&2
    exit 1
fi

for cmd in find du df sort head realpath mktemp mv mkdir rm date stat; do
    command -v "$cmd" >/dev/null 2>&1 || {
        printf 'ไม่พบคำสั่งที่จำเป็น: %s\n' "$cmd" >&2
        exit 1
    }
done

[[ -t 0 && -t 1 ]] || {
    printf 'กรุณารันใน Terminal แบบ interactive\n' >&2
    exit 1
}

HOME_DIR=$(realpath -e -- "$HOME") || exit 1
ROOT="$HOME_DIR"
STORE="$HOME_DIR/.local/share/disk-tui-quarantine"
DRY_RUN=1

mkdir -p -- "$STORE" || exit 1
STORE=$(realpath -e -- "$STORE") || exit 1

WORK=$(mktemp -d) || exit 1
LIST="$WORK/candidates"
trap 'rm -rf -- "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

pause() {
    printf '\n'
    read -r -p 'กด Enter เพื่อกลับเมนู...' _
}

header() {
    printf '\033[2J\033[H'
    printf '=== Disk Scan & Cleanup TUI ===\n'
    printf 'โฟลเดอร์: %q\n' "$ROOT"
    printf 'พื้นที่กักกัน: %q\n' "$STORE"
    if (( DRY_RUN )); then
        printf 'โหมด: DRY-RUN — ยังไม่ย้ายไฟล์\n\n'
    else
        printf 'โหมด: ย้ายเข้าพื้นที่กักกัน — ต้องยืนยันทุกครั้ง\n\n'
    fi
}

ask_days() {
    local value
    read -r -p 'ไฟล์ที่ไม่ได้แก้ไขเกินกี่วัน? [30]: ' value
    value=${value:-30}
    [[ "$value" =~ ^[0-9]{1,5}$ ]] || {
        printf 'กรุณาระบุจำนวนวันเป็นเลขจำนวนเต็ม 0–99999\n'
        return 1
    }
    DAYS=$((10#$value))
}

choose_root() {
    local input resolved
    read -r -p 'ระบุโฟลเดอร์สำหรับสแกน [ว่าง = HOME]: ' input
    input=${input:-"$HOME_DIR"}

    resolved=$(realpath -e -- "$input" 2>/dev/null) || {
        printf 'ไม่พบโฟลเดอร์นี้\n'
        return
    }

    [[ -d "$resolved" && -r "$resolved" && -x "$resolved" ]] || {
        printf 'โฟลเดอร์ไม่สามารถเข้าถึงได้\n'
        return
    }

    ROOT="$resolved"
    printf 'เปลี่ยนโฟลเดอร์แล้ว\n'
}

# Cleanup is restricted to the user's HOME.
# Scanning elsewhere is still permitted.
safe_cleanup_scope() {
    local scope=$1

    case "$scope" in
        "$HOME_DIR"|"$HOME_DIR"/*) ;;
        *)
            printf 'เพื่อความปลอดภัย อนุญาตทำความสะอาดเฉพาะภายใน HOME\n'
            return 1
            ;;
    esac

    case "$scope" in
        "$STORE"|"$STORE"/*)
            printf 'ใช้เมนูพื้นที่กักกันแทนการทำความสะอาดโฟลเดอร์นี้\n'
            return 1
            ;;
    esac

    [[ -d "$scope" && -w "$scope" && -x "$scope" ]] || {
        printf 'โฟลเดอร์นี้ไม่มีสิทธิ์สำหรับจัดการไฟล์\n'
        return 1
    }
}

disk_usage() {
    df -h -- "$ROOT" "$STORE"
}

folder_usage() {
    printf 'ขนาดโฟลเดอร์ระดับแรก รวมไฟล์ที่อยู่ตรงระดับนี้\n'
    printf 'อาจใช้เวลาหากมีไฟล์จำนวนมาก\n\n'
    du -x -h --max-depth=1 -- "$ROOT" 2>"$WORK/errors" |
        sort -hr |
        head -n 25
    if [[ -s "$WORK/errors" ]]; then
        printf '\nหมายเหตุ: มีบางรายการที่อ่านไม่ได้\n'
    fi
}

large_files() {
    local mb path size
    read -r -p 'ขนาดขั้นต่ำ MB [100]: ' mb
    mb=${mb:-100}
    [[ "$mb" =~ ^[0-9]{1,7}$ ]] || {
        printf 'ขนาดไม่ถูกต้อง\n'
        return
    }
    mb=$((10#$mb))

    printf '\nไฟล์ขนาดมากกว่า %s MiB — สูงสุด 30 รายการ\n' "$mb"

    find "$ROOT" -xdev \
        \( -path "$STORE" -o -path "$STORE/*" \) -prune -o \
        -type f -size "+${mb}M" -printf '%s\t%p\0' \
        2>"$WORK/errors" |
        sort -z -nr |
        head -z -n 30 > "$WORK/large"

    while IFS= read -r -d '' entry; do
        size=${entry%%$'\t'*}
        path=${entry#*$'\t'}
        printf '%12s bytes  %q\n' "$size" "$path"
    done < "$WORK/large"

    if [[ -s "$WORK/errors" ]]; then
        printf '\nหมายเหตุ: มีบางรายการที่อ่านไม่ได้\n'
    fi
}

build_candidates() {
    local scope=$1 mode=$2

    : > "$LIST"

    case "$mode" in
        temp)
            find "$scope" -xdev \
                \( -path "$STORE" -o -path "$STORE/*" \) -prune -o \
                -type f -uid "$EUID" -mtime "+$DAYS" \
                \( -iname '*.tmp' -o -iname '*.temp' \) -print0 \
                > "$LIST" 2>"$WORK/errors"
            ;;
        log)
            find "$scope" -xdev \
                \( -path "$STORE" -o -path "$STORE/*" \) -prune -o \
                -type f -uid "$EUID" -mtime "+$DAYS" \
                -iname '*.log' -print0 \
                > "$LIST" 2>"$WORK/errors"
            ;;
        backup)
            find "$scope" -xdev \
                \( -path "$STORE" -o -path "$STORE/*" \) -prune -o \
                -type f -uid "$EUID" -mtime "+$DAYS" \
                \( -iname '*.bak' -o -iname '*.old' \) -print0 \
                > "$LIST" 2>"$WORK/errors"
            ;;
        cache)
            find "$scope" -xdev \
                \( -path "$STORE" -o -path "$STORE/*" \) -prune -o \
                -type f -uid "$EUID" -mtime "+$DAYS" -print0 \
                > "$LIST" 2>"$WORK/errors"
            ;;
    esac

    if [[ -s "$WORK/errors" ]]; then
        printf 'หมายเหตุ: สแกนได้ไม่ครบ มีบางรายการที่อ่านไม่ได้\n'
    fi
}

review_and_quarantine() {
    local path bytes count=0 total=0 reply batch dest
    local moved=0 failed=0

    printf '\nตัวอย่างรายการ สูงสุด 20 ไฟล์:\n'
    while IFS= read -r -d '' path; do
        bytes=$(stat -c '%s' -- "$path" 2>/dev/null) || continue
        count=$((count + 1))
        total=$((total + bytes))
        if (( count <= 20 )); then
            printf '%12s bytes  %q\n' "$bytes" "$path"
        fi
    done < "$LIST"

    printf '\nพบ %s ไฟล์ ขนาดเนื้อหารวม %s bytes\n' "$count" "$total"
    printf 'ขนาดนี้ไม่ใช่พื้นที่ดิสก์ที่จะคืนได้แน่นอน\n'

    (( count > 0 )) || return

    if (( DRY_RUN )); then
        printf 'DRY-RUN: ไม่ย้ายและไม่ลบไฟล์ใด ๆ\n'
        return
    fi

    printf '\nควรปิดโปรแกรมที่ใช้ไฟล์เหล่านี้ก่อน\n'
    read -r -p 'พิมพ์ MOVE เพื่อย้ายรายการทั้งหมดเข้าพื้นที่กักกัน: ' reply
    [[ "$reply" == MOVE ]] || {
        printf 'ยกเลิกแล้ว\n'
        return
    }

    batch=$(mktemp -d "$STORE/batch-$(date +%Y%m%d-%H%M%S)-XXXXXX") ||
        return

    while IFS= read -r -d '' path; do
        # Recheck immediately before moving.
        [[ -f "$path" && ! -L "$path" && -O "$path" ]] || {
            failed=$((failed + 1))
            continue
        }

        dest="$batch/files$path"
        if mkdir -p -- "${dest%/*}" &&
            mv -n -- "$path" "$dest" &&
            [[ ! -e "$path" && -f "$dest" ]]; then
            moved=$((moved + 1))
        else
            failed=$((failed + 1))
            printf 'ย้ายไม่ได้: %q\n' "$path"
        fi
    done < "$LIST"

    printf '\nย้ายแล้ว %s ไฟล์ / ข้ามหรือไม่สำเร็จ %s ไฟล์\n' "$moved" "$failed"
    printf 'ชุดกักกัน: %q\n' "${batch##*/}"
    printf 'ยังไม่ได้ลบถาวร และอาจยังไม่คืนพื้นที่ดิสก์\n'
}

cleanup() {
    local mode=$1 scope="$ROOT"

    if [[ "$mode" == cache ]]; then
        scope=$(realpath -e -- "${XDG_CACHE_HOME:-"$HOME_DIR/.cache"}" \
            2>/dev/null) || {
            printf 'ไม่พบโฟลเดอร์ cache\n'
            return
        }
        printf 'Cache scope: %q\n' "$scope"
        printf 'คำเตือน: บางแอปอาจมีข้อมูลสำคัญใน cache ควรปิดแอปก่อน\n'
    fi

    safe_cleanup_scope "$scope" || return
    ask_days || return
    build_candidates "$scope" "$mode"
    review_and_quarantine
}

list_batches() {
    local path
    printf 'พื้นที่กักกันทั้งหมด:\n'
    du -sh -- "$STORE"
    printf '\nชุดที่มี:\n'
    while IFS= read -r -d '' path; do
        printf '%q\n' "${path##*/}"
    done < <(
        find "$STORE" -mindepth 1 -maxdepth 1 \
            -type d -name 'batch-*' -print0
    )
}

restore_batch() {
    local name batch path original reply
    local restored=0 skipped=0

    list_batches
    read -r -p 'ชื่อชุดที่ต้องการคืนไฟล์: ' name

    [[ "$name" == batch-* && "$name" != */* ]] || {
        printf 'ชื่อชุดไม่ถูกต้อง\n'
        return
    }

    batch="$STORE/$name"
    [[ -d "$batch/files" && ! -L "$batch" && ! -L "$batch/files" ]] || {
        printf 'ไม่พบชุดนี้\n'
        return
    }

    read -r -p 'พิมพ์ RESTORE เพื่อคืนไฟล์ โดยไม่เขียนทับของเดิม: ' reply
    [[ "$reply" == RESTORE ]] || return

    while IFS= read -r -d '' path; do
        original=${path#"$batch/files"}

        case "$original" in
            "$HOME_DIR"/*) ;;
            *) skipped=$((skipped + 1)); continue ;;
        esac

        if [[ -e "$original" || -L "$original" ]]; then
            printf 'ข้าม เพราะปลายทางมีอยู่แล้ว: %q\n' "$original"
            skipped=$((skipped + 1))
            continue
        fi

        # Reject parent paths redirected outside HOME by symlinks.
        local parent
        parent=$(realpath -m -- "${original%/*}") || {
            skipped=$((skipped + 1))
            continue
        }
        case "$parent" in
            "$HOME_DIR"|"$HOME_DIR"/*) ;;
            *) skipped=$((skipped + 1)); continue ;;
        esac

        if mkdir -p -- "${original%/*}" &&
            mv -n -- "$path" "$original" &&
            [[ ! -e "$path" && -f "$original" ]]; then
            restored=$((restored + 1))
        else
            skipped=$((skipped + 1))
        fi
    done < <(find "$batch/files" -type f -print0)

    printf 'คืนไฟล์แล้ว %s / ข้ามหรือไม่สำเร็จ %s\n' "$restored" "$skipped"
}

purge_quarantine() {
    local reply path failed=0

    list_batches

    if (( DRY_RUN )); then
        printf '\nDRY-RUN: ไม่ลบพื้นที่กักกัน\n'
        return
    fi

    printf '\nคำเตือน: จะลบทุกชุดในพื้นที่กักกันแบบถาวร\n'
    printf 'หลังลบแล้ว สคริปต์นี้ไม่สามารถคืนไฟล์ให้ได้\n'
    read -r -p 'พิมพ์ DELETE QUARANTINE เพื่อยืนยัน: ' reply
    [[ "$reply" == 'DELETE QUARANTINE' ]] || {
        printf 'ยกเลิกแล้ว\n'
        return
    }

    while IFS= read -r -d '' path; do
        rm -rf --one-file-system -- "$path" || failed=$((failed + 1))
    done < <(
        find "$STORE" -mindepth 1 -maxdepth 1 \
            -type d -name 'batch-*' -print0
    )

    printf 'ล้างพื้นที่กักกันเสร็จ / รายการที่ลบไม่สำเร็จ: %s\n' "$failed"
    df -h -- "$STORE"
}

while true; do
    header
    printf '%s\n' \
        '1) เลือกโฟลเดอร์สแกน' \
        '2) ดูพื้นที่ดิสก์' \
        '3) ดูโฟลเดอร์ที่ใช้พื้นที่มาก' \
        '4) ค้นหาไฟล์ขนาดใหญ่' \
        '5) ตรวจสอบ/กักกันไฟล์ .tmp และ .temp ที่เก่า' \
        '6) ตรวจสอบ/กักกันไฟล์ .log ที่เก่า' \
        '7) ตรวจสอบ/กักกันไฟล์ .bak และ .old ที่เก่า' \
        '8) ตรวจสอบ/กักกัน cache ของผู้ใช้ที่เก่า' \
        '9) เปิด/ปิด Dry-run' \
        '10) ดูพื้นที่กักกัน' \
        '11) คืนไฟล์จากชุดกักกัน' \
        '12) ล้างพื้นที่กักกันถาวร' \
        '0) ออกจากโปรแกรม'

    printf '\n'
    read -r -p 'เลือกเมนู: ' choice || break
    printf '\n'

    case "$choice" in
        1) choose_root ;;
        2) disk_usage ;;
        3) folder_usage ;;
        4) large_files ;;
        5) cleanup temp ;;
        6) cleanup log ;;
        7) cleanup backup ;;
        8) cleanup cache ;;
        9)
            DRY_RUN=$((1 - DRY_RUN))
            if (( DRY_RUN )); then
                printf 'เปิด Dry-run แล้ว\n'
            else
                printf 'ปิด Dry-run แล้ว การย้าย/ลบยังต้องยืนยัน\n'
            fi
            ;;
        10) list_batches ;;
        11) restore_batch ;;
        12) purge_quarantine ;;
        0) break ;;
        *) printf 'กรุณาเลือกเมนูที่มีอยู่\n' ;;
    esac

    pause
done