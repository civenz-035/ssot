#!/usr/bin/env bash
# ============================================================
# File: shared/personal/sound_cut.sh
# Description: SSOT Audio Extraction & Trimming Helper (ffmpeg)
# ============================================================

# Fallback color functions if core/01-colors.sh is not loaded yet
if ! declare -f c >/dev/null 2>&1; then
    c() {
        shift
        [[ $# -gt 0 && "$1" =~ ^[bdiu]{1,4}$ ]] && shift
        printf "%s" "$*"
    }
fi
if ! declare -f cn >/dev/null 2>&1; then
    cn() {
        shift
        [[ $# -gt 0 && "$1" =~ ^[bdiu]{1,4}$ ]] && shift
        printf "%s\n" "$*"
    }
fi

sound_cut() {
    local input=""
    local output=""
    local format=""
    local bitrate="192k"
    local start=""
    local duration=""
    local end_time=""
    local volume=""
    local speed=""
    local fade_in=""
    local fade_out=""
    local do_loudnorm=0
    local is_mono=0
    local overwrite=0
    local dry_run=0
    local no_cb=0
    local positional=()

    _sound_cut_usage() {
        c 45 b "✂ SOUND CUT"; c 245 "" " — "; cn 220 b "Universal Audio Helper (SSOT)"
        cn 245 "" "─────────────────────────────────────────────────────────────"
        c 226 b "Usage: "; cn 255 "" "sound_cut [input] [output] [options]"
        c 226 b "       "; cn 255 "" "sound_cut <file> [start] [end|duration] [output]"
        echo ""
        c 51 b "Positional Shortcuts (Quick Mode):"
        echo ""
        c 245 "" "  sound_cut song.mp4"; cn 250 "" "                     # Extracts to \$PWD/song.mp3 (Default: current dir)"
        c 245 "" "  sound_cut song.mp4 out.wav"; cn 250 "" "             # Auto-detects wav format"
        c 245 "" "  sound_cut song.mp4 /path/to/dir/"; cn 250 "" "       # Exports to specific folder"
        c 245 "" "  sound_cut song.mp4 00:30 01:45"; cn 250 "" "         # Cuts from 00:30 to 01:45"
        c 245 "" "  sound_cut song.mp4 00:30 45 out.mp3"; cn 250 "" "    # Start 00:30, duration 45s"
        echo ""
        c 51 b "Options & Flags:"
        echo ""
        c 220 "" "  -i, --input <file>"; cn 255 "" "        Input audio/video file (Required if not 1st arg)"
        c 220 "" "  -o, --output <path>"; cn 255 "" "       Output filename or directory (Auto-detected)"
        c 220 "" "  -f, -fmt, --format <fmt>"; cn 255 "" "  Format: mp3, m4a, wav, flac, ogg, aac, opus, copy"
        c 220 "" "  -b, --bitrate <rate>"; cn 255 "" "      Audio bitrate e.g., 128k, 192k, 320k (Default: 192k)"
        c 220 "" "  -s, --start <time>"; cn 255 "" "        Start offset (e.g. 00:01:20 or 80)"
        c 220 "" "  -e, --to, --end <time>"; cn 255 "" "    End timestamp (e.g. 00:02:15 or 135)"
        c 220 "" "  -t, --duration <time>"; cn 255 "" "     Extract duration (e.g. 30 or 00:00:30)"
        echo ""
        c 51 b "Audio Enhancements & Filters:"
        echo ""
        c 220 "" "  -v, --vol, --volume <val>"; cn 255 "" " Volume multiplier (e.g. 1.5, 2.0, 0.8, or 150%)"
        c 220 "" "  -n, --norm, --loudnorm"; cn 255 "" "   Apply EBU R128 loudness normalization"
        c 220 "" "  -m, --mono"; cn 255 "" "               Downmix audio to 1 channel (mono)"
        c 220 "" "      --speed <factor>"; cn 255 "" "     Playback tempo speed (0.5 to 2.0, e.g. 1.25)"
        c 220 "" "      --fade-in <sec>"; cn 255 "" "      Fade-in duration in seconds (e.g. 2)"
        c 220 "" "      --fade-out <sec>"; cn 255 "" "     Fade-out duration in seconds (e.g. 3)"
        echo ""
        c 51 b "Control & System Flags:"
        echo ""
        c 220 "" "  -y, --yes, --overwrite"; cn 255 "" "   Overwrite existing output file without confirmation"
        c 220 "" "  -p, --preview, --dry-run"; cn 255 "" " Show ffmpeg command without executing"
        c 220 "" "      --no-cb"; cn 255 "" "              Skip auto-copying output path to clipboard"
        c 220 "" "  -h, --help"; cn 255 "" "               Show this help guide"
        cn 245 "" "─────────────────────────────────────────────────────────────"
    }

    # 1. Parse options and arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                input="$2"; shift 2 ;;
            -o|--output)
                output="$2"; shift 2 ;;
            -f|-fmt|--format)
                format="$2"; shift 2 ;;
            -b|--bitrate)
                bitrate="$2"; shift 2 ;;
            -s|--start)
                start="$2"; shift 2 ;;
            -e|--to|--end)
                end_time="$2"; shift 2 ;;
            -t|--duration)
                duration="$2"; shift 2 ;;
            -v|--vol|--volume)
                volume="$2"; shift 2 ;;
            -n|--norm|--loudnorm)
                do_loudnorm=1; shift ;;
            -m|--mono)
                is_mono=1; shift ;;
            --speed)
                speed="$2"; shift 2 ;;
            --fade-in)
                fade_in="$2"; shift 2 ;;
            --fade-out)
                fade_out="$2"; shift 2 ;;
            -y|--yes|--overwrite)
                overwrite=1; shift ;;
            -p|--preview|--dry-run)
                dry_run=1; shift ;;
            --no-cb)
                no_cb=1; shift ;;
            -h|--help)
                _sound_cut_usage; return 0 ;;
            -*)
                cn 196 b "✗ Unknown option: $1 (use -h for help)"
                return 1
                ;;
            *)
                positional+=("$1"); shift ;;
        esac
    done

    # 2. Map positional parameters if flags were not explicitly used
    if [[ -z "$input" && ${#positional[@]} -gt 0 ]]; then
        input="${positional[0]}"
        unset "positional[0]"
        positional=("${positional[@]}")
    fi

    # Check if remaining positional args represent [output], or [start] [end|duration] [output]
    if [[ ${#positional[@]} -gt 0 ]]; then
        for pos in "${positional[@]}"; do
            # Timestamp check: contains ":" or pure numeric
            if [[ -z "$start" && "$pos" =~ ^([0-9]+:)?[0-9]+(:[0-9]+)?(\.[0-9]+)?$ ]]; then
                start="$pos"
            elif [[ -z "$end_time" && -z "$duration" && "$pos" =~ ^([0-9]+:)?[0-9]+(:[0-9]+)?(\.[0-9]+)?$ ]]; then
                # If value has colon or is timestamp, default to end_time; if purely small seconds, end_time works identically
                end_time="$pos"
            elif [[ -z "$output" ]]; then
                output="$pos"
            fi
        done
    fi

    # 3. Validation: ffmpeg installed?
    if ! command -v ffmpeg >/dev/null 2>&1; then
        cn 196 b "✗ Error: ffmpeg is not installed or not in PATH."
        cn 245 "" "  Install via: sudo apt install ffmpeg (WSL/Linux) or pkg install ffmpeg (Termux)"
        return 1
    fi

    # 4. Validation: Input file
    if [[ -z "$input" ]]; then
        cn 196 b "✗ Error: Input file is required."
        echo ""
        _sound_cut_usage
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        cn 196 b "✗ Error: File not found: $input"
        return 1
    fi

    # 5. Resolve Output Path and Format
    local in_dir in_base in_name in_ext
    in_dir="$(dirname "$input")"
    in_base="$(basename "$input")"
    in_name="${in_base%.*}"
    in_ext="${in_base##*.}"

    # Auto-detect format from explicit output filename if format was not specified
    if [[ -z "$format" && -n "$output" ]]; then
        local out_target_ext="${output##*.}"
        case "${out_target_ext,,}" in
            mp3|m4a|wav|flac|ogg|aac|opus)
                format="${out_target_ext,,}"
                ;;
        esac
    fi

    # Default format to mp3 if still empty
    [[ -z "$format" ]] && format="mp3"
    format="${format,,}"

    # Handle output resolution
    if [[ -z "$output" ]]; then
        # Default: in current working directory ($PWD) with target format extension
        if [[ "$format" == "copy" ]]; then
            output="${PWD}/${in_name}_cut.${in_ext}"
        else
            output="${PWD}/${in_name}.${format}"
        fi
    elif [[ -d "$output" || "$output" == */ ]]; then
        # Output is a directory: place file inside
        local out_clean_dir="${output%/}"
        mkdir -p "$out_clean_dir" 2>/dev/null
        if [[ "$format" == "copy" ]]; then
            output="${out_clean_dir}/${in_name}_cut.${in_ext}"
        else
            output="${out_clean_dir}/${in_name}.${format}"
        fi
    else
        # Output is a filename/path: ensure it has the right extension if none was provided
        if [[ "$output" != *.* ]]; then
            if [[ "$format" == "copy" ]]; then
                output="${output}.${in_ext}"
            else
                output="${output}.${format}"
            fi
        fi
    fi

    # Prevent accidental self-overwrite if input == output
    local full_in full_out
    full_in="$(readlink -f "$input" 2>/dev/null || realpath "$input" 2>/dev/null || echo "$input")"
    full_out="$(readlink -f "$output" 2>/dev/null || realpath "$output" 2>/dev/null || echo "$output")"
    if [[ "$full_in" == "$full_out" ]]; then
        local out_target_dir
        out_target_dir="$(dirname "$output")"
        output="${out_target_dir}/${in_name}_cut.${format}"
        cn 214 b "⚠ Warning: Output matches input. Renamed output to: $(basename "$output")"
    fi

    # Check if target already exists and overwrite flag is off
    if [[ -f "$output" && $overwrite -eq 0 && $dry_run -eq 0 ]]; then
        c 226 b "⚠ File exists: "; cn 255 "" "$output"
        printf "  Overwrite? [y/N]: "
        read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            cn 245 "" "→ Operation cancelled."
            return 0
        fi
    fi

    # 6. Build ffmpeg audio filters (-af)
    local af_filters=()

    # Volume filter (e.g. 1.5, 200%, 0.8)
    if [[ -n "$volume" ]]; then
        # Clean up any trailing % if needed or pass directly to volume filter
        if [[ "$volume" =~ ^[0-9]+%$ ]]; then
            af_filters+=("volume=${volume}")
        else
            af_filters+=("volume=${volume}")
        fi
    fi

    # Loudness normalization
    if [[ $do_loudnorm -eq 1 ]]; then
        af_filters+=("loudnorm")
    fi

    # Speed adjustment
    if [[ -n "$speed" ]]; then
        af_filters+=("atempo=${speed}")
    fi

    # Fade-in
    if [[ -n "$fade_in" ]]; then
        af_filters+=("afade=t=in:ss=0:d=${fade_in}")
    fi

    # Fade-out (works best when duration is specified)
    if [[ -n "$fade_out" ]]; then
        if [[ -n "$duration" ]]; then
            local fade_start
            fade_start="$(awk "BEGIN {print $duration - $fade_out}" 2>/dev/null || echo "")"
            if [[ -n "$fade_start" && $(awk "BEGIN {print ($fade_start > 0)?1:0}") -eq 1 ]]; then
                af_filters+=("afade=t=out:st=${fade_start}:d=${fade_out}")
            fi
        fi
    fi

    # 7. Assemble ffmpeg command
    local cmd=("ffmpeg" "-hide_banner" "-loglevel" "warning" "-stats")

    # Overwrite flag
    cmd+=("-y")

    # Time seeking
    if [[ -n "$start" ]]; then
        cmd+=("-ss" "$start")
    fi

    if [[ -n "$end_time" ]]; then
        cmd+=("-to" "$end_time")
    elif [[ -n "$duration" ]]; then
        cmd+=("-t" "$duration")
    fi

    # Input file
    cmd+=("-i" "$input")

    # Strip video stream
    cmd+=("-vn")

    # Audio channels
    if [[ $is_mono -eq 1 ]]; then
        cmd+=("-ac" "1")
    fi

    # Audio filters (cannot use with copy)
    if [[ ${#af_filters[@]} -gt 0 ]]; then
        if [[ "$format" == "copy" ]]; then
            cn 214 b "⚠ Warning: Filters ignored in 'copy' mode. Switching to format 'mp3'."
            format="mp3"
        fi
        local joined_filters
        joined_filters=$(IFS=,; echo "${af_filters[*]}")
        cmd+=("-af" "$joined_filters")
    fi

    # Format-specific codec and bitrate
    case "$format" in
        copy)
            cmd+=("-c:a" "copy")
            ;;
        mp3)
            cmd+=("-c:a" "libmp3lame" "-b:a" "$bitrate" "-ar" "44100")
            ;;
        m4a|aac)
            cmd+=("-c:a" "aac" "-b:a" "$bitrate" "-ar" "44100")
            ;;
        wav)
            cmd+=("-c:a" "pcm_s16le" "-ar" "44100")
            ;;
        flac)
            cmd+=("-c:a" "flac")
            ;;
        ogg)
            cmd+=("-c:a" "libvorbis" "-b:a" "$bitrate")
            ;;
        opus)
            cmd+=("-c:a" "libopus" "-b:a" "$bitrate")
            ;;
        *)
            cn 196 b "✗ Unknown format: $format"
            return 1
            ;;
    esac

    # Destination output
    cmd+=("$output")

    # 8. User feedback card
    cn 245 "" "─────────────────────────────────────────────────────────────"
    c 45 b "✂ SOUND CUT"; c 245 "" "  ▶  "; cn 51 b "$(basename "$input")"
    c 245 "" "  ├─ Input:   "; cn 250 "" "$input"
    c 245 "" "  ├─ Output:  "; cn 46 b "$output"
    c 245 "" "  ├─ Format:  "; c 220 b "$format"; [[ "$format" != "copy" && "$format" != "wav" && "$format" != "flac" ]] && { c 245 "" " ("; c 220 "" "$bitrate"; c 245 "" ")"; }
    echo ""
    if [[ -n "$start" || -n "$end_time" || -n "$duration" ]]; then
        c 245 "" "  ├─ Range:   "; cn 226 "" "${start:-00:00:00} → ${end_time:-duration ${duration:-end}}"
    fi
    if [[ ${#af_filters[@]} -gt 0 ]]; then
        c 245 "" "  ├─ Filters: "; cn 208 "" "${af_filters[*]}"
    fi
    cn 245 "" "─────────────────────────────────────────────────────────────"

    # Preview / Dry run
    if [[ $dry_run -eq 1 ]]; then
        c 226 b "[DRY-RUN] "; cn 250 "" "${cmd[*]}"
        return 0
    fi

    # 9. Execute ffmpeg
    c 245 "" "Processing audio... "
    if "${cmd[@]}"; then
        echo ""
        local fsize=""
        if [[ -f "$output" ]]; then
            fsize="$(du -h "$output" 2>/dev/null | awk '{print $1}')"
        fi
        c 46 b "✔ Complete: "; c 255 b "$output"; [[ -n "$fsize" ]] && { c 245 "" " ("; c 45 "" "$fsize"; c 245 "" ")"; }
        echo ""

        # SSOT clipboard integration
        if [[ $no_cb -eq 0 ]] && declare -f cb_copy >/dev/null 2>&1; then
            if cb_copy "$output" 2>/dev/null; then
                c 245 "" "  ↳ "; cn 10 "" "📋 Output path copied to clipboard"
            fi
        fi
        return 0
    else
        echo ""
        cn 196 b "✗ ffmpeg execution failed. Check errors above."
        return 1
    fi
}

# Backward compatibility & ergonomic aliases
extract_audio() {
    sound_cut "$@"
}
alias soundcut="sound_cut"
alias aucut="sound_cut"

export capt="/mnt/c/Users/User/Videos/Captures"
export scrn="/mnt/c/Users/User/Desktop/screenshots/screen"
export sound="/mnt/c/Users/User/Desktop/sound/sound"