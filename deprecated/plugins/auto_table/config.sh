#!/bin/bash
_C -q -f "set_" "draw_"
_C -q -f _pvar
# --- 1. Config & Defaults ---
_config_def() {
  # --- 1. Config & Defaults ---
  # -- setup cn mode
	while (( $# > 0 )); do
		case "$1" in
			-cm|--color-mode|colors)
         		set_ "COLOR_MODE" "${2:-no}" ; shift 2 ;;
			-t|--title|t)
          		set_ "BN_TITLE" "${2:-SUPERBOOM PATH}" 	
          		set_ "BN_TITLE_COLOR" "${3:-118}"
				set_ "BN_TITLE_STYLE" "${4:-b}"
				shift 4
				;;
			-b|--border-config|bc)
				set_ "BN_BORDER_CHAR" "${2:-━}"
          		set_ "BN_BORDER_COLOR" "${3:-92}"
          		set_ "BN_BORDER_STYLE"  "${4:-b}"
				shift 4
				;;
			-l|--label-config|lc)
				set_ "BN_LABEL_COLOR"  "${2:-190}"       # เทาสว่าง
    			set_ "BN_LABEL_STYLE"  "${3:-d}"         # dim
    			set_ "BN_VAL_COLOR"    "${4:-82}"       # 202
    			set_ "BN_VAL_STYLE"    "${5:-b}"
				shift 5
				;;
			-s|--sep|s)
				set_ "BN_SEP" "${2:- : }" ; shift 2 ;;
			*) break  ;;
		 esac
	done	
}
