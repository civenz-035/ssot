#!/usr/bin/env bash
# ============================================================
# File: shared/personal/video_cut.sh
# Description: SSOT Video Trimming & Compression Helper (ffmpeg)
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

video_cut() {
    local input=""
    local output=""
    local format=""
    local start=""
    local duration=""
    local end_time=""
    local quality="med"       # low, med, high or numeric CRF
    local crf=""
    local resolution=""      # 1080p, 720p, 480p, 360p or custom e.g. -2:720
    local v_bitrate=""
    local a_bitrate="128k"
    local v_codec="libx264"
    local preset="fast"
    local speed=""
    local fps=""
    local is_copy=0
    local is_mute=0
    local is_gif=0
    local overwrite=0
    local dry_run=0
    local no_cb=0
    local target_size_mb=""
    local positional=()

    _video_cut_usage() {
        c 45 b "🎬 VIDEO CUT"; c 245 "" " — "; cn 220 b "Universal Video Editor & Compressor (SSOT)"
        cn 245 "" "─────────────────────────────────────────────────────────────"
        c 226 b "Usage: "; cn 255 "" "video_cut [input] [output] [options]"
        c 226 b "       "; cn 255 "" "video_cut <file> [start] [end|duration] [output]"
        echo ""
        c 51 b "Positional Shortcuts (Quick Mode):"
        echo ""
        c 245 "" "  video_cut clip.mp4"; cn 250 "" "                     # Compresses clip.mp4 -> clip_edit.mp4 (720p, CRF 28)"
        c 245 "" "  video_cut clip.mp4 out.mp4"; cn 250 "" "             # Compress to custom output"
        c 245 "" "  video_cut clip.mp4 /path/to/dir/"; cn 250 "" "       # Exports to target directory"
        c 245 "" "  video_cut clip.mp4 00:15 01:30"; cn 250 "" "         # Cuts from 00:15 to 01:30"
        c 245 "" "  video_cut clip.mp4 00:10 30 out.mp4"; cn 250 "" "    # Cuts starting at 00:10 for 30s"
        echo ""
        c 51 b "Trimming Options:"
        echo ""
        c 220 "" "  -s, --start <time>"; cn 255 "" "        Start offset (e.g. 00:01:20 or 80)"
        c 220 "" "  -e, --to, --end <time>"; cn 255 "" "    End timestamp (e.g. 00:02:15 or 135)"
        c 220 "" "  -t, --duration <time>"; cn 255 "" "     Extract duration (e.g. 30 or 00:00:30)"
        c 220 "" "  -c, --copy"; cn 255 "" "                Lossless fast cut (stream copy, no re-encode)"
        echo ""
        c 51 b "Compression & Quality Options:"
        echo ""
        c 220 "" "  -q, --quality <level>"; cn 255 "" "     low (CRF 32), med (CRF 28, default), high (CRF 23), or custom CRF 0-51"
        c 220 "" "  -r, --res, --resolution <res>"; cn 255 "" " Target resolution: 1080p, 720p, 480p, 360p, or scale string (e.g. -2:720)"
        c 220 "" "  -b, --bitrate <rate>"; cn 255 "" "      Target video bitrate (e.g. 1M, 800k, 2500k)"
        c 220 "" "      --size <MB>"; cn 255 "" "           Target file size in MB (auto-calculates video bitrate)"
        c 220 "" "      --preset <speed>"; cn 255 "" "      Encoding speed: ultrafast, fast (default), medium, slow"
        c 220 "" "      --hevc, --x265"; cn 255 "" "        Use H.265/HEVC codec for maximum compression"
        echo ""
        c 51 b "Audio & Speed Filters:"
        echo ""
        c 220 "" "  -an, --mute, --no-audio"; cn 255 "" "   Remove audio track from video"
        c 220 "" "  -ab, --audio-bitrate <rate>"; cn 255 "" "Audio bitrate (default: 128k)"
        c 220 "" "      --speed <factor>"; cn 255 "" "     Playback speed (e.g. 0.5, 1.25, 2.0)"
        c 220 "" "      --fps <num>"; cn 255 "" "          Target frames per second (e.g. 30, 24)"
        c 220 "" "      --gif"; cn 255 "" "                Convert video clip directly to high-quality GIF"
        echo ""
        c 51 b "Control & System Flags:"
        echo ""
        c 220 "" "  -y, --yes, --overwrite"; cn 255 "" "   Overwrite existing output without confirmation"
        c 220 "" "  -p, --preview, --dry-run"; cn 255 "" " Show ffmpeg command without executing"
        c 220 "" "      --no-cb"; cn 255 "" "              Skip auto-copying output path to clipboard"
        c 220 "" "  -h, --help"; cn 255 "" "               Show this help guide"
        cn 245 "" "─────────────────────────────────────────────────────────────"
    }

    # 1. Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                input="$2"; shift 2 ;;
            -o|--output)
                output="$2"; shift 2 ;;
            -s|--start)
                start="$2"; shift 2 ;;
            -e|--to|--end)
                end_time="$2"; shift 2 ;;
            -t|--duration)
                duration="$2"; shift 2 ;;
            -q|--quality)
                quality="$2"; shift 2 ;;
            -r|--res|--resolution)
                resolution="$2"; shift 2 ;;
            -b|--bitrate)
                v_bitrate="$2"; shift 2 ;;
            -ab|--audio-bitrate)
                a_bitrate="$2"; shift 2 ;;
            --preset)
                preset="$2"; shift 2 ;;
            --hevc|--x265)
                v_codec="libx265"; shift ;;
            --size|--target-size)
                target_size_mb="$2"; shift 2 ;;
            --speed)
                speed="$2"; shift 2 ;;
            --fps)
                fps="$2"; shift 2 ;;
            -c|--copy)
                is_copy=1; shift ;;
            -an|--mute|--no-audio)
                is_mute=1; shift ;;
            --gif)
                is_gif=1; shift ;;
            -y|--yes|--overwrite)
                overwrite=1; shift ;;
            -p|--preview|--dry-run)
                dry_run=1; shift ;;
            --no-cb)
                no_cb=1; shift ;;
            -h|--help)
                _video_cut_usage; return 0 ;;
            -*)
                cn 196 b "✗ Unknown option: $1 (use -h for help)"
                return 1
                ;;
            *)
                positional+=("$1"); shift ;;
        esac
    done

    # 2. Map positional parameters
    if [[ -z "$input" && ${#positional[@]} -gt 0 ]]; then
        input="${positional[0]}"
        unset "positional[0]"
        positional=("${positional[@]}")
    fi

    if [[ ${#positional[@]} -gt 0 ]]; then
        for pos in "${positional[@]}"; do
            if [[ -z "$start" && "$pos" =~ ^([0-9]+:)?[0-9]+(:[0-9]+)?(\.[0-9]+)?$ ]]; then
                start="$pos"
            elif [[ -z "$end_time" && -z "$duration" && "$pos" =~ ^([0-9]+:)?[0-9]+(:[0-9]+)?(\.[0-9]+)?$ ]]; then
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
        cn 196 b "✗ Error: Input video file is required."
        echo ""
        _video_cut_usage
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        cn 196 b "✗ Error: File not found: $input"
        return 1
    fi

    # 5. Resolve Output Path and Extension
    local in_base in_name in_ext
    in_base="$(basename "$input")"
    in_name="${in_base%.*}"
    in_ext="${in_base##*.}"
    format="${in_ext,,}"

    if [[ $is_gif -eq 1 ]]; then
        format="gif"
    fi

    # Resolve output name if specified with extension
    if [[ -n "$output" ]]; then
        local out_target_ext="${output##*.}"
        if [[ "$output" == *.* ]]; then
            format="${out_target_ext,,}"
        fi
    fi

    if [[ -z "$output" ]]; then
        output="${PWD}/${in_name}_edit.${format}"
    elif [[ -d "$output" || "$output" == */ ]]; then
        local out_clean_dir="${output%/}"
        mkdir -p "$out_clean_dir" 2>/dev/null
        output="${out_clean_dir}/${in_name}_edit.${format}"
    else
        if [[ "$output" != *.* ]]; then
            output="${output}.${format}"
        fi
    fi

    # Prevent accidental self-overwrite
    local full_in full_out
    full_in="$(readlink -f "$input" 2>/dev/null || realpath "$input" 2>/dev/null || echo "$input")"
    full_out="$(readlink -f "$output" 2>/dev/null || realpath "$output" 2>/dev/null || echo "$output")"
    if [[ "$full_in" == "$full_out" ]]; then
        local out_target_dir
        out_target_dir="$(dirname "$output")"
        output="${out_target_dir}/${in_name}_edit_new.${format}"
        cn 214 b "⚠ Warning: Output matches input. Renamed output to: $(basename "$output")"
    fi

    # Target file collision check
    if [[ -f "$output" && $overwrite -eq 0 && $dry_run -eq 0 ]]; then
        c 226 b "⚠ File exists: "; cn 255 "" "$output"
        printf "  Overwrite? [y/N]: "
        read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            cn 245 "" "→ Operation cancelled."
            return 0
        fi
    fi

    # 6. Parse Quality / CRF
    case "${quality,,}" in
        high) crf="23" ;;
        med|medium|"") crf="28" ;;
        low)  crf="32" ;;
        *)
            if [[ "$quality" =~ ^[0-9]+$ ]]; then
                crf="$quality"
            else
                crf="28"
            fi
            ;;
    esac

    # If target size is specified, calculate required video bitrate
    if [[ -n "$target_size_mb" && "$target_size_mb" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        local v_dur=""
        if [[ -n "$duration" && "$duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            v_dur="$duration"
        elif command -v ffprobe >/dev/null 2>&1; then
            v_dur="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | awk '{print int($1)}')"
        fi

        if [[ -n "$v_dur" && "$v_dur" -gt 0 ]]; then
            # total_bits = size_mb * 8192 kbits; total_bitrate = total_bits / v_dur; v_bitrate = total_bitrate - 128k
            local total_kbits calculated_v_kbits
            total_kbits="$(awk "BEGIN {print int($target_size_mb * 8192)}")"
            calculated_v_kbits="$(awk "BEGIN {k=int($total_kbits / $v_dur) - 128; print (k > 100)?k:100}")"
            v_bitrate="${calculated_v_kbits}k"
            is_copy=0
        fi
    fi

    # 7. Build Video & Audio Filters
    local vf_filters=()
    local af_filters=()

    # Resolution scaling
    if [[ -n "$resolution" ]]; then
        case "${resolution,,}" in
            1080|1080p) vf_filters+=("scale=-2:1080") ;;
            720|720p)   vf_filters+=("scale=-2:720") ;;
            480|480p)   vf_filters+=("scale=-2:480") ;;
            360|360p)   vf_filters+=("scale=-2:360") ;;
            *)          vf_filters+=("scale=${resolution}") ;;
        esac
        is_copy=0
    fi

    # FPS adjustment
    if [[ -n "$fps" ]]; then
        vf_filters+=("fps=${fps}")
        is_copy=0
    fi

    # Playback speed adjustment
    if [[ -n "$speed" ]]; then
        local setpts_val
        setpts_val="$(awk "BEGIN {print 1.0 / $speed}" 2>/dev/null || echo "1.0")"
        vf_filters+=("setpts=${setpts_val}*PTS")
        af_filters+=("atempo=${speed}")
        is_copy=0
    fi

    # If GIF mode requested
    if [[ $is_gif -eq 1 ]]; then
        is_copy=0
        local gif_scale="${resolution:-scale=-2:480}"
        [[ "$gif_scale" =~ ^(1080|720|480|360)p?$ ]] && gif_scale="scale=-2:${gif_scale%p}"
        vf_filters=("fps=${fps:-15}" "$gif_scale" "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse")
    fi

    # 8. Assemble ffmpeg command
    local cmd=("ffmpeg" "-hide_banner" "-loglevel" "warning" "-stats")
    cmd+=("-y")

    # Fast seeking before input
    if [[ -n "$start" ]]; then
        cmd+=("-ss" "$start")
    fi

    if [[ -n "$end_time" ]]; then
        cmd+=("-to" "$end_time")
    elif [[ -n "$duration" ]]; then
        cmd+=("-t" "$duration")
    fi

    cmd+=("-i" "$input")

    # Stream Copy (Lossless fast cut mode)
    if [[ $is_copy -eq 1 && ${#vf_filters[@]} -eq 0 && -z "$v_bitrate" && $is_mute -eq 0 && $is_gif -eq 0 ]]; then
        cmd+=("-c" "copy")
    elif [[ $is_gif -eq 1 ]]; then
        local joined_vf
        joined_vf=$(IFS=,; echo "${vf_filters[*]}")
        cmd+=("-vf" "$joined_vf")
    else
        # Video encoding
        cmd+=("-c:v" "$v_codec")
        cmd+=("-preset" "$preset")

        if [[ -n "$v_bitrate" ]]; then
            cmd+=("-b:v" "$v_bitrate" "-maxrate" "$v_bitrate" "-bufsize" "$(( ${v_bitrate//[!0-9]/} * 2 ))k")
        else
            cmd+=("-crf" "$crf")
        fi

        # Faststart for smooth web & mobile streaming playback
        cmd+=("-movflags" "+faststart")

        # Color pixel format for high compatibility
        cmd+=("-pix_fmt" "yuv420p")

        # Video filters
        if [[ ${#vf_filters[@]} -gt 0 ]]; then
            local joined_vf
            joined_vf=$(IFS=,; echo "${vf_filters[*]}")
            cmd+=("-vf" "$joined_vf")
        fi

        # Audio settings
        if [[ $is_mute -eq 1 ]]; then
            cmd+=("-an")
        else
            cmd+=("-c:a" "aac" "-b:a" "$a_bitrate")
            if [[ ${#af_filters[@]} -gt 0 ]]; then
                local joined_af
                joined_af=$(IFS=,; echo "${af_filters[*]}")
                cmd+=("-af" "$joined_af")
            fi
        fi
    fi

    cmd+=("$output")

    # 9. Status Card Display
    local orig_size=""
    if [[ -f "$input" ]]; then
        orig_size="$(du -h "$input" 2>/dev/null | awk '{print $1}')"
    fi

    cn 245 "" "─────────────────────────────────────────────────────────────"
    c 45 b "🎬 VIDEO CUT"; c 245 "" "  ▶  "; cn 51 b "$(basename "$input")"
    c 245 "" "  ├─ Input:      "; c 250 "" "$input"; [[ -n "$orig_size" ]] && { c 245 "" " ("; c 220 "" "$orig_size"; c 245 "" ")"; }; echo ""
    c 245 "" "  ├─ Output:     "; cn 46 b "$output"
    if [[ $is_gif -eq 1 ]]; then
        c 245 "" "  ├─ Mode:       "; cn 208 b "GIF Animation"
    elif [[ $is_copy -eq 1 && ${#vf_filters[@]} -eq 0 && -z "$v_bitrate" ]]; then
        c 245 "" "  ├─ Mode:       "; cn 226 b "Stream Copy (Lossless Fast Cut)"
    else
        c 245 "" "  ├─ Codec:      "; c 220 b "$v_codec"; c 245 "" " (preset: "; c 250 "" "$preset"; c 245 "" ")"; echo ""
        if [[ -n "$v_bitrate" ]]; then
            c 245 "" "  ├─ Bitrate:    "; cn 220 "" "$v_bitrate"
        else
            c 245 "" "  ├─ Quality:    "; c 220 "" "CRF $crf"; c 245 "" " ($quality)"; echo ""
        fi
        [[ -n "$resolution" ]] && { c 245 "" "  ├─ Resolution: "; cn 220 "" "$resolution"; }
    fi
    if [[ -n "$start" || -n "$end_time" || -n "$duration" ]]; then
        c 245 "" "  ├─ Range:      "; cn 226 "" "${start:-00:00:00} → ${end_time:-duration ${duration:-end}}"
    fi
    if [[ $is_mute -eq 1 ]]; then
        c 245 "" "  ├─ Audio:      "; cn 196 "" "Muted (-an)"
    fi
    cn 245 "" "─────────────────────────────────────────────────────────────"

    # Preview / Dry run
    if [[ $dry_run -eq 1 ]]; then
        c 226 b "[DRY-RUN] "; cn 250 "" "${cmd[*]}"
        return 0
    fi

    # 10. Execute ffmpeg
    c 245 "" "Processing video... "
    if "${cmd[@]}"; then
        echo ""
        local new_size=""
        if [[ -f "$output" ]]; then
            new_size="$(du -h "$output" 2>/dev/null | awk '{print $1}')"
        fi

        c 46 b "✔ Complete: "; c 255 b "$output"
        if [[ -n "$new_size" ]]; then
            c 245 "" " ("; c 45 "" "$new_size"; c 245 "" ")"
            if [[ -n "$orig_size" ]]; then
                c 245 "" " [was "; c 240 "" "$orig_size"; c 245 "" "]"
            fi
        fi
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

# Ergonomic aliases
alias vdocut="video_cut"
alias videocut="video_cut"
alias vcut="video_cut"
alias compress_video="video_cut"
