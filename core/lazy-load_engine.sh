#!/bin/bash
#-- load_maneger.sh
#  -- source orch

# -- block-engine loader
_m(){
	_check_ -f 'm' &&
	m "$@"
}

gt_lazyload(){
	_C -f gt && gt "$@"
}
alias gt='gt_lazyload'
