#!/bin/bash
#-- load_maneger.sh
#  -- source orch

# -- block-engine loader
_m(){
	_check_ -f 'm' &&
	m "$@"
}

gt_lazyload(){

	if ! declare -f "gt" &> /dev/null ; then
		  _C -f gt 2&>/dev/null && echo "LOADED"
			gt "$@"
	else
			gt "$@"
	fi
}	

fgt(){
	while (( $# > 0 )); do
			case "$1" in
					-a|--all|--update|--synce)
							gt_lazyload sync all --add -m "daily update"
							shift
							;;
				 	*) 
							gt_lazyload "$@"
							break
							;;
			esac
	done		
	(( $# <= 0 )) && gt_lazyload
}
