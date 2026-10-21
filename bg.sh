#!/usr/bin/env bash
# ============================================================
# Test Suite for cbg (Background Color Engine & Flag Tests)
# Path: /home/joez/ssot/bg.sh
# ============================================================
source /home/joez/ssot/core/01-colors.sh

TOTAL_TESTS=0
PASSED_TESTS=0

to_hex_or_repr() {
    printf '%q' "$1"
}

assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "  \033[32m[PASS]\033[0m $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  \033[31m[FAIL]\033[0m $test_name"
        echo -e "    Expected: $(to_hex_or_repr "$expected")"
        echo -e "    Actual:   $(to_hex_or_repr "$actual")"
    fi
}

echo "=========================================="
echo " Running cbg Automated Verification Suite"
echo "=========================================="

# ------------------------------------------------------------
# 1. Default Behavior (No Flags)
# ------------------------------------------------------------
echo -e "\n[Group 1: Default Behavior]"
out_raw=$(cbg r "Hello")
assert_equals "cbg default output format" $'\033[48;5;196mHello\033[49m' "$out_raw"

out_with_nl=$(cbg r "Hello"; echo -n "__EOF__")
if [[ "$out_with_nl" == *"Hello"$'\033[49m__EOF__' ]]; then
    echo -e "  \033[32m[PASS]\033[0m Default cbg does NOT append trailing newline"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  \033[31m[FAIL]\033[0m Default cbg appended an unexpected newline"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# ------------------------------------------------------------
# 2. Flag -n (Newline)
# ------------------------------------------------------------
echo -e "\n[Group 2: Flag -n (Newline)]"
out_n_capture=$(cbg -n r "Hello"; echo -n "__EOF__")
expected_n_capture=$'\033[48;5;196mHello\033[49m\n__EOF__'
assert_equals "cbg -n appends single trailing newline" "$expected_n_capture" "$out_n_capture"

out_nl_long=$(cbg --new r "Hello"; echo -n "__EOF__")
assert_equals "cbg --new (long flag) appends single trailing newline" "$expected_n_capture" "$out_nl_long"

# ------------------------------------------------------------
# 3. Flag -e (Escape sequence interpretation)
# ------------------------------------------------------------
echo -e "\n[Group 3: Flag -e (Escape Sequences)]"
# Flag -e alone should interpret \n and \t inside string, but should NOT add a trailing newline
out_e_capture=$(cbg -e g 'A\nB\tC'; echo -n "__EOF__")
expected_e_capture=$'\033[48;5;82mA\nB\tC\033[49m__EOF__'
assert_equals "cbg -e expands escapes WITHOUT trailing newline" "$expected_e_capture" "$out_e_capture"

# ------------------------------------------------------------
# 4. Combined Flags (-n with -e, -ne, -en)
# ------------------------------------------------------------
echo -e "\n[Group 4: Combined Flags (-n, -e)]"
out_en_capture=$(cbg -e -n g 'A\nB'; echo -n "__EOF__")
expected_en_capture=$'\033[48;5;82mA\nB\033[49m\n__EOF__'
assert_equals "cbg -e -n has expanded escapes and EXACTLY ONE trailing newline" "$expected_en_capture" "$out_en_capture"

out_ne_capture=$(cbg -ne g 'A\nB'; echo -n "__EOF__")
assert_equals "cbg -ne (compound flag) works identically" "$expected_en_capture" "$out_ne_capture"

out_en_comp=$(cbg -en g 'A\nB'; echo -n "__EOF__")
assert_equals "cbg -en (compound flag) works identically" "$expected_en_capture" "$out_en_comp"

# ------------------------------------------------------------
# 5. Inner Reset Preservation (Nested Color ANSI)
# ------------------------------------------------------------
echo -e "\n[Group 5: Nested Colors & Inner Reset Preservation]"
input_ansi=$'\033[33mYellow\033[0m Normal'
expected_ansi=$'\033[48;5;196m\033[33mYellow\033[0m\033[48;5;196m Normal\033[49m'
actual_ansi=$(cbg r "$input_ansi")
assert_equals "Preserve bg across real byte \\033[0m reset" "$expected_ansi" "$actual_ansi"

actual_e_ansi=$(cbg -e r '\033[33mYellow\033[0m Normal')
assert_equals "Preserve bg across \\033[0m when using -e" "$expected_ansi" "$actual_e_ansi"

# ------------------------------------------------------------
# 6. PS1 Mode (-ps) Tests
# ------------------------------------------------------------
echo -e "\n[Group 6: PS1 Prompt Mode]"
expected_ps1=$'\[\033[48;5;196m\]User@Host\[\033[49m\]'
actual_ps1=$(cbg -ps r "User@Host")
assert_equals "PS1 basic outer wrapping (\\[ \\])" "$expected_ps1" "$actual_ps1"

input_nested_ansi=$'\033[32mGreen\033[0m Normal'
expected_ps1_nested=$'\[\033[48;5;196m\]\033[32mGreen\033[0m\[\033[48;5;196m\] Normal\[\033[49m\]'
actual_ps1_nested=$(cbg -ps r "$input_nested_ansi")
assert_equals "PS1 inner nested wrapping (\\[ \\])" "$expected_ps1_nested" "$actual_ps1_nested"

input_auto="Status: \[\033[33mActive\033[0m\]"
actual_auto=$(cbg r "$input_auto")
if [[ "$actual_auto" == $'\[\033[48;5;196m\]'* ]]; then
    echo -e "  \033[32m[PASS]\033[0m Auto-detected bracket and applied PS1 wrapper"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  \033[31m[FAIL]\033[0m Auto-detection failed"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

out_ps_n=$(cbg -ps -n b "Prompt"; echo -n "__EOF__")
expected_ps_n=$'\[\033[48;5;33m\]Prompt\[\033[49m\]\n__EOF__'
assert_equals "cbg -ps -n combines prompt wrapper with newline" "$expected_ps_n" "$out_ps_n"

# ------------------------------------------------------------
# 7. Color Shorthand & Numeric Color Mappings
# ------------------------------------------------------------
echo -e "\n[Group 7: Color Shorthands]"
assert_equals "Color 'r' maps to 196"   $'\033[48;5;196mX\033[49m' "$(cbg r X)"
assert_equals "Color 'lr' maps to 203"  $'\033[48;5;203mX\033[49m' "$(cbg lr X)"
assert_equals "Color 'g' maps to 82"    $'\033[48;5;82mX\033[49m'  "$(cbg g X)"
assert_equals "Color 'lg' maps to 46"   $'\033[48;5;46mX\033[49m'  "$(cbg lg X)"
assert_equals "Color 'y' maps to 226"   $'\033[48;5;226mX\033[49m' "$(cbg y X)"
assert_equals "Color 'cr' maps to 51"   $'\033[48;5;51mX\033[49m'  "$(cbg cr X)"
assert_equals "Color 'b' maps to 33"    $'\033[48;5;33mX\033[49m'  "$(cbg b X)"
assert_equals "Color 'ora' maps to 208" $'\033[48;5;208mX\033[49m' "$(cbg ora X)"
assert_equals "Color 'gr' maps to 244"  $'\033[48;5;244mX\033[49m' "$(cbg gr X)"
assert_equals "Numeric color 123"       $'\033[48;5;123mX\033[49m' "$(cbg 123 X)"

# ------------------------------------------------------------
# 8. cbgl Convenience Function
# ------------------------------------------------------------
echo -e "\n[Group 8: cbgl Convenience Function]"
out_cbgl=$(cbgl ora "Test"; echo -n "__EOF__")
expected_cbgl=$'\033[48;5;208mTest\033[49m\n__EOF__'
assert_equals "cbgl automatically appends newline" "$expected_cbgl" "$out_cbgl"

# ============================================================
# Summary & Visual Inspection
# ============================================================
echo ""
echo "=========================================="
echo " Test Summary: Passed $PASSED_TESTS of $TOTAL_TESTS test cases"
echo "=========================================="

echo -e "\n--- Visual Verification Display ---"
cbg -n r   "  [cbg -n r]   Red Background with newline  "
cbg -n g   "  [cbg -n g]   Green Background with newline  "
cbg -n b   "  [cbg -n b]   Blue Background with newline  "
cbg -n ora "  [cbg -n ora] Orange Background with newline  "
cbg -n y   "  [cbg -n y]   Yellow Background with newline  "
cbg -n gr  "  [cbg -n gr]  Grey Background with newline  "
echo -n "  Inline test (no -n): "
cbg r " Red "
cbg g " Green "
cbg b " Blue "
echo " (<- end of inline)"

echo -e "\n  Multi-line with -e -n:"
cbg -e -n g "    Line 1: Green Background\n    Line 2:\tTabbed text on Green"

echo -e "\n  Nested color inside background:"
cbg -e -n r "    Red Background with \033[33;1mBold Yellow Text\033[0m still on Red Background!"

echo "=========================================="
echo " Test execution finished."
echo "=========================================="

if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    exit 0
else
    exit 1
fi