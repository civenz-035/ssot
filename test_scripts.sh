#!/usr/bin/env bash
# ------------------------------------------------------------
# File: test_scripts.sh
# ------------------------------------------------------------

source "$HOME/.maths-helper/maths.sh" || exit 1


mul=$(mth "$a*$b")
add=$(mth "$a+$b")
sub=$(mth "$a-$b")
div=$(mth "$a/$b")
rem=$(mth "$a%$b")




a=10 
b=10 
echo "$a * $b = $mul"
echo "$a + $b = $add"
echo "$a - $b = $sub"
echo "$a / $b = $div"
echo "$a % $b = $rem"
echo "$a ^ $b = $ยกกำลัง"
echo "sqrt($a) = $รากที่สอง"
echo "cbrt($a) = $รากที่สาม"
echo "abs($a) = $ค่าสัมบูรณ์"
echo "ceil($a) = $ปัดเศษขึ้น"
echo "floor($a) = $ปัดเศษลง"
echo "round($a) = $ปัดเศษใกล้"
echo "sin($a) = $ตรีโกณมิติ"
echo "exp($a) = $เลขยกกำลังฐาน e"
echo "log($a) = $ลอการิทึมธรรมชาติ"
echo "log10($a) = $ลอการิทึมฐาน 10"
echo "pow2($a) = $เลขชี้กำลังฐาน 2"

           