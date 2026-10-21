
#!/usr/bin/env bash
# ============================================================
# File: test_cbg.sh
# Target: cbg() background-only color helper
# Requires: Bash 4+
#
# Usage:
#   bash test_cbg.sh
#   bash test_cbg.sh --quick
#   bash test_cbg.sh --visual
#   bash test_cbg.sh --stress
#
# Environment:
#   CBG_SOURCE=/path/to/cbg.sh
#
# Test levels:
#   Unit       : arguments, output bytes, reset handling
#   Integration: option combinations, PS1 markers
#   Regression : edge cases and malformed inputs
#   Stress     : randomized payloads
# ============================================================
#source "$ssot/core/01-colors.sh"
set -uo pipefail

MODE="${1:-all}"
PASS=0
FAIL=0
SKIP=0
TOTAL=0
CBG_SOURCE="$ssot/core/01-colors.sh"
# ------------------------------------------------------------
# Load target
# ------------------------------------------------------------

if ! declare -F cbg >/dev/null 2>&1; then
    if [[ -n "${CBG_SOURCE:-}" && -f "$CBG_SOURCE" ]]; then
        # shellcheck source=/dev/null
        source "$CBG_SOURCE"
    else
        printf 'ERROR: cbg() is not loaded.\n' >&2
        printf 'Set CBG_SOURCE=/path/to/cbg.sh\n' >&2
        printf 'Or source cbg() before running this script.\n' >&2
        exit 2
    fi
fi

# ------------------------------------------------------------
# Test framework
# ------------------------------------------------------------

fail() {
    printf '\nFAIL: %s\n' "$1" >&2
    shift

    if (($#)); then
        printf '  %s\n' "$@" >&2
    fi

    ((FAIL += 1))
    ((TOTAL += 1))
}

pass() {
    printf 'PASS: %s\n' "$1"
    ((PASS += 1))
    ((TOTAL += 1))
}

skip() {
    printf 'SKIP: %s\n' "$1"
    ((SKIP += 1))
    ((TOTAL += 1))
}

# Capture output without stripping trailing newlines.
capture() {
    CAPTURED_OUTPUT="$(cbg "$@")"
}

# Compare exact output bytes using Bash variables.
assert_eq() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" \
            "Expected: $(printf '%q' "$expected")" \
            "Actual:   $(printf '%q' "$actual")"
    fi
}

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" \
            "Missing: $(printf '%q' "$needle")" \
            "Actual:  $(printf '%q' "$haystack")"
    fi
}

assert_not_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" \
            "Unexpected: $(printf '%q' "$needle")"
    fi
}

# ------------------------------------------------------------
# Expected ANSI sequences
# ------------------------------------------------------------

ESC=$'\033'

BG196="${ESC}[48;5;196m"
BG203="${ESC}[48;5;203m"
BG82="${ESC}[48;5;82m"
BG46="${ESC}[48;5;46m"
BG226="${ESC}[48;5;226m"
BG51="${ESC}[48;5;51m"
BG33="${ESC}[48;5;33m"
BG208="${ESC}[48;5;208m"
BG244="${ESC}[48;5;244m"

RESET="${ESC}[0m"
RESET_SHORT="${ESC}[m"
RESET_BG="${ESC}[49m"

# ------------------------------------------------------------
# Test groups
# ------------------------------------------------------------

test_basic() {
    printf '\n=== BASIC OUTPUT ===\n'

    capture 196 hello
    assert_eq 'basic: foreground-independent BG prefix' \
        "${BG196}hello${RESET_BG}" "$CAPTURED_OUTPUT"

    capture 203 'hello world'
    assert_eq 'basic: text with spaces' \
        "${BG203}hello world${RESET_BG}" "$CAPTURED_OUTPUT"

    capture 196 ''
    assert_eq 'basic: empty text' \
        "${BG196}${RESET_BG}" "$CAPTURED_OUTPUT"

    capture 196 '123'
    assert_eq 'basic: numeric text' \
        "${BG196}123${RESET_BG}" "$CAPTURED_OUTPUT"

    capture 196 'a' 'b' 'c'
    assert_eq 'basic: multiple text arguments are joined' \
        "${BG196}a b c${RESET_BG}" "$CAPTURED_OUTPUT"
}

test_color_aliases() {
    printf '\n=== COLOR ALIASES ===\n'

    local -a cases=(
        'r 196'
        'lr 203'
        'g 82'
        'lg 46'
        'y 226'
        'cr 51'
        'b 33'
        'ora 208'
        'gr 244'
    )

    local item alias expected actual

    for item in "${cases[@]}"; do
        read -r alias expected <<<"$item"

        capture "$alias" x
        actual="$CAPTURED_OUTPUT"

        local expected_seq="${ESC}[48;5;${expected}m"

        assert_eq "alias: $alias" \
            "${expected_seq}x${RESET_BG}" "$actual"
    done
}

test_reset_handling() {
    printf '\n=== RESET HANDLING ===\n'

    capture 196 "A${RESET}B"

    assert_eq 'reset: ESC[0m reapplies background' \
        "${BG196}A${RESET}${BG196}B${RESET_BG}" \
        "$CAPTURED_OUTPUT"

    capture 196 "A${RESET_SHORT}B"

    assert_eq 'reset: ESC[m reapplies background' \
        "${BG196}A${RESET_SHORT}${BG196}B${RESET_BG}" \
        "$CAPTURED_OUTPUT"

    capture 196 "A${RESET_BG}B"

    assert_eq 'reset: ESC[49m reapplies background' \
        "${BG196}A${BG196}B${RESET_BG}" \
        "$CAPTURED_OUTPUT"

    capture 196 "${RESET}"

    assert_eq 'reset: reset-only payload' \
        "${BG196}${RESET}${BG196}${RESET_BG}" \
        "$CAPTURED_OUTPUT"

    capture 196 "${RESET}${RESET_SHORT}${RESET_BG}"

    assert_eq 'reset: consecutive reset sequences' \
        "${BG196}${RESET}${BG196}${RESET_SHORT}${BG196}${BG196}${RESET_BG}" \
        "$CAPTURED_OUTPUT"
}

test_options() {
    printf '\n=== OPTIONS ===\n'

    capture -n 196 hello
    assert_eq 'option: -n adds newline' \
        "${BG196}hello${RESET_BG}" "$CAPTURED_OUTPUT"

    capture --new 196 hello
    assert_eq 'option: --new accepted' \
        "${BG196}hello${RESET_BG}" "$CAPTURED_OUTPUT"

    capture -e 196 '\e[31mRED'
    assert_eq 'option: -e expands escapes' \
        "${BG196}${ESC}[31mRED${RESET_BG}" "$CAPTURED_OUTPUT"

    capture -ne 196 '\e[31mRED'
    assert_eq 'option: -ne expands and adds newline' \
        "${BG196}${ESC}[31mRED${RESET_BG}" "$CAPTURED_OUTPUT"

    capture -- 196 '-leading-text'
    assert_eq 'option: -- ends option parsing' \
        "${BG196}-leading-text${RESET_BG}" "$CAPTURED_OUTPUT"
}

test_ps_markers() {
    printf '\n=== PS MARKERS ===\n'

    capture -ps 196 hello

    assert_eq 'PS: explicit PS mode wraps escapes' \
        "\[${BG196}\]hello\[${RESET_BG}\]" \
        "$CAPTURED_OUTPUT"

    capture -ps 196 "A${RESET}B"

    assert_eq 'PS: inner background sequence is wrapped' \
        "\[${BG196}\]A${RESET}\[${BG196}\]B\[${RESET_BG}\]" \
        "$CAPTURED_OUTPUT"

    capture 196 '\[literal-marker\]'

    assert_eq 'PS: marker detection triggers PS wrapping' \
        "\[${BG196}\]\[literal-marker\]\[${RESET_BG}\]" \
        "$CAPTURED_OUTPUT"
}

test_argument_edges() {
    printf '\n=== ARGUMENT EDGES ===\n'

    capture
    assert_eq 'edge: no arguments' '' "$CAPTURED_OUTPUT"

    capture 196
    assert_eq 'edge: color without text' \
        "${BG196}${RESET_BG}" "$CAPTURED_OUTPUT"

    capture 196 ''
    assert_eq 'edge: explicit empty string' \
        "${BG196}${RESET_BG}" "$CAPTURED_OUTPUT"

    capture -h
    assert_contains 'help: displays usage' \
        "$CAPTURED_OUTPUT" 'Usage:'

    capture --help
    assert_contains 'help: long option displays usage' \
        "$CAPTURED_OUTPUT" 'Usage:'
}

test_escape_payloads() {
    printf '\n=== ESCAPE PAYLOADS ===\n'

    capture -e 196 '\n'
    assert_eq 'escape: newline expansion' \
        "${BG196}" "$CAPTURED_OUTPUT"

    capture -e 196 '\tTAB'
    assert_eq 'escape: tab expansion' \
        "${BG196}"$'\tTAB'"${RESET_BG}" "$CAPTURED_OUTPUT"

    capture -e 196 '\033[31mRED'
    assert_eq 'escape: octal ESC expansion' \
        "${BG196}${ESC}[31mRED${RESET_BG}" \
        "$CAPTURED_OUTPUT"

    capture -e 196 '\x1b[31mRED'
    assert_eq 'escape: hexadecimal ESC expansion' \
        "${BG196}${ESC}[31mRED${RESET_BG}" \
        "$CAPTURED_OUTPUT"
}

test_invalid_colors() {
    printf '\n=== INVALID COLOR INPUT ===\n'

    local color

    for color in \
        abc \
        -1 \
        999 \
        256 \
        16x \
        '1;31' \
        '$(touch /tmp/cbg-pwned)'
    do
        capture "$color" X

        # This suite checks whether the input is passed directly
        # into the ANSI background-color sequence.
        #
        # It does not assume invalid colors must be rejected:
        # that is a policy decision for the implementation.
        assert_contains "invalid-color probe: $color" \
            "$CAPTURED_OUTPUT" "$ESC[48;5;"
    done
}

test_random_helpers() {
    printf '\n=== RANDOM HELPER INTEGRATION ===\n'

    if ! declare -F random_core >/dev/null 2>&1; then
        skip 'random_core unavailable: rand/rc fallback tests skipped'
        return
    fi

    local output

    capture rc X
    output="$CAPTURED_OUTPUT"

    assert_contains 'random: rc emits background sequence' \
        "$output" "$ESC[48;5;"

    capture rand X
    output="$CAPTURED_OUTPUT"

    assert_contains 'random: rand emits background sequence' \
        "$output" "$ESC[48;5;"
}

test_visual() {
    printf '\n=== VISUAL TEST ===\n'

    local i

    for ((i = 16; i <= 231; i++)); do
        printf '%s' "$(cbg "$i" '  ')"
        if (((i - 15) % 18 == 0)); then
            printf '\n'
        fi
    done

    printf '\n'
    printf '%s\n' 'Visual palette test complete.'
}

test_stress() {
    printf '\n=== STRESS TEST ===\n'

    local i payload actual expected

    for ((i = 1; i <= 1000; i++)); do
        case $((i % 8)) in
            0) payload="plain-$i" ;;
            1) payload="A${RESET}B-$i" ;;
            2) payload="A${RESET_SHORT}B-$i" ;;
            3) payload="A${RESET_BG}B-$i" ;;
            4) payload="space   space-$i" ;;
            5) payload=$'tab\ttext-'$i ;;
            6) payload="dollar-\$-backslash-\\-$i" ;;
            7) payload="unicode-ไทย-日本語-$i" ;;
        esac

        actual="$(cbg 196 "$payload")"

        expected="${BG196}${payload//"$RESET"/"$RESET$BG196"}"
        expected="${expected//"$RESET_SHORT"/"$RESET_SHORT$BG196"}"
        expected="${expected//"$RESET_BG"/"$BG196"}${RESET_BG}"

        if [[ "$actual" != "$expected" ]]; then
            fail "stress case $i" \
                "Payload: $(printf '%q' "$payload")"
        else
            ((PASS += 1))
            ((TOTAL += 1))
        fi
    done

    printf 'Stress iterations: 1000\n'
}

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------

case "$MODE" in
    --quick)
        test_basic
        test_color_aliases
        test_reset_handling
        test_options
        ;;
    --visual)
        test_visual
        exit 0
        ;;
    --stress)
        test_stress
        ;;
    all)
        test_basic
        test_color_aliases
        test_reset_handling
        test_options
        test_ps_markers
        test_argument_edges
        test_escape_payloads
        test_invalid_colors
        test_random_helpers
        test_stress
        ;;
    *)
        printf 'Usage: %s [--quick|--visual|--stress]\n' "$0" >&2
        exit 2
        ;;
esac

printf '\n'
printf '============================================================\n'
printf 'TOTAL: %d | PASS: %d | FAIL: %d | SKIP: %d\n' \
    "$TOTAL" "$PASS" "$FAIL" "$SKIP"
printf '============================================================\n'

if ((FAIL > 0)); then
    exit 1
fi

exit 0
```
