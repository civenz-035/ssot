#!/bin/bash
_C -f "set_" "draw_"
# --- 1. Config & Defaults ---
_config_def() {
  # --- 1. Config & Defaults ---
  # -- setup cn mode
	while (( $# >= )); do
		case "$1" in
			-cm|--color-mode|colors)
          set_ "COLOR_MODE" "$2" ; shift 2 ;;
			-tt|--title|t)
          set_ "BN_TITLE" "$2" ; shift 2 ;;
			-tc|--title-color|tc)		
          set_ "BN_TITLE_COLOR" "$2" ; shift 2 ;;
			-ts|--title-style|ts)
					set_ "BN_TITLE_STYLE" "$2" ; shift 2 ;;
			-b|--border-config|bc)
					set_ "BN_BORDER_CHAR" "$2"
          set_ "BN_BORDER_COLOR" "$3"
          set_ "BN_BORDER_STYLE"  "$4"
					shift 4 
					;;
			-l|--label-config|lc)
					set_ "BN_LABEL_COLOR"  "$2"       # เทาสว่าง
    			set_ "BN_LABEL_STYLE"  "$3"         # dim
    			set_ "BN_VAL_COLOR"    "$4"       # 202
    			set_ "BN_VAL_STYLE"    "$5"
					shift 5
					;;
			-s|--sep|s)
					set_ "BN_SEP" " $2 " ; shift 2 ;;
			*) break  ;;
	  esac
	done	
}
# --- 2 Config & rc ---
_config_rc() {
    config_rc "$@"
}
config_rc(){
  
    set_ "COLOR_MODE"                 "no"          # auto / manual
    set_ "BN_TITLE"                 "SUPERBOOM PATH"
    set_ "BN_TITLE_COLOR"           "118"       # ส้ม
    set_ "BN_TITLE_STYLE"           "b"         # bold

    set_ "BN_BORDER_CHAR"           "━"         # ม
    set_ "BN_BORDER_COLOR"          "92"
    set_ "BN_BORDER_STYLE"          "b"

    set_ "BN_LABEL_COLOR"           "190 "       # เทาสว่าง
    set_ "BN_LABEL_STYLE"           "d"         # dim
    set_ "BN_VAL_COLOR"             "82"       # 202
    set_ "BN_VAL_STYLE"             "b"
   set_ "BN_SEP"                   " : "
}




