#!/bin/bash
# SECTION 1, the functions in this section are also defined in MDTools
function validate_var {
	local B
	if [ -z "$1" ]; then
		exit 1
	fi
	eval B='$'$1
	if [ -z "$B" ]; then
		echo "$1 Not Set"
		exit 1
	fi
}

function validate_dir {
	if [ -z "$1" ]; then
		exit 2
	fi
	if [ ! -d "$1" ]; then
		exit 1
	fi
}

function show_var {
	local fmt
	local B
	if [ -z "$1" ]; then
		return
	fi
	if [ ! -z "$2" ]; then
		fmt=$1
		shift
	fi
	eval B='$'$1
	if [ -z "$B" ]; then
		if [ -z "$fmt" ]; then
			echo "$1 Not Set"
		else
			printf "$fmt %s\n" $1 "Not Set"
		fi
	else
		if [ -z "$fmt" ]; then
			echo "$1 => $B "
		else
			printf "$fmt => %s\n" $1 $B
		fi
	fi
}
# end of SECTION 1

<<DOCUMENT
NAME
    print_document - search the DOCUMENT in the file and print
SYNOPSIS
	print_document [filename]
DESCRIPTION
	if there's no filename, the filename defaults value of ENV BASH_SOURCE[1].
DOCUMENT
function print_document {
	local file=${BASH_SOURCE[1]}
	if [ $# -eq 1 ]; then
		file=$1	
	fi
	awk '{if(/^<<DOCUMENT/){to_print=1}else if(/^DOCUMENT/){to_print=0} else if(to_print==1) print($0)}' $file
}

<<DOCUMENT
NAME 
    print_args - print function arguments
SYNOPSIS
    print_args "$@"            - for program parameters
    print_args "${ARRAY[@]}"   - for bash array
DOCUMENT
function print_args {
	local my_pos=1
	local i	
	for i in "$@"; do 
		echo "$my_pos: $i"
		((my_pos=$my_pos+1))
	done
}

<<DOCUMENT
NAME 
    sed_c - simulate command "sed -ic", which works in CentOS
DOCUMENT
function sed_c { 
	if [ "$#" -lt 2 ]; then
		return 1
	fi
	local file="${@: -1}"
	[ -f $file ] || return 1
	local tmp=$(mktemp)
	if sed "$@" >$tmp; then
		cp $tmp $file
	fi
	rm -f $tmp
}


function abort {
	if [ $# -gt 0 ]; then
		echo "$@"
	fi
	exit 1
}

function abortn {
	if [ $# -eq 0 ]; then
		exit 1
	fi
	local rtnVal=$1 
	shift
	if [ $# -gt 0 ]; then
		echo "$@"
	fi
	exit $rtnVal
}

function in_array { #  keyOrValue, arrayKeysOrValues  
	local e
	for e in "${@:2}"; do 
		[[ "$e" == "$1" ]] && return 0 
	done
	return 1
}

function load_server_cfg {
	[[ $# -eq 1 ]] || return 1
	local IFSOLD=$IFS
	local a=0
	local rtn=1
	IFS=
	while read -r line; do 
		if (( a == 0 )); then
			if [ "$line" == "HOSTS" ]; then
				a=1
			fi
			continue
		elif (( a == 1 )); then
			if ! [[ $line =~ ^[[:space:]]+ ]]; then
				break 
			fi
		else
			continue
		fi
		if [[ $line =~ ^[[:space:]]+([a-z0-9A-Z_]+)[[:space:]]+([a-z0-9A-Z_]+)[[:space:]]+([a-z0-9A-Z_]+) ]]; then
			[[ ${1^^} == ${BASH_REMATCH[1]^^} ]] || continue 
			USER=${BASH_REMATCH[3]}
			HOST=${BASH_REMATCH[1]}
			PORT=${BASH_REMATCH[2]}
			rtn=0
			#printf "Found => User:%20s HOST:%20s Port:%20s <=matched %s\n" $USER $HOST $PORT $1
		fi
	done <~/.vsys.conf
	IFS=$IFSOLD
	return $rtn
}

function try_help {
	local i
	for i in ${BASH_ARGV[@]}; do
		if [[ $i == "--help" ]]; then
			print_document ${BASH_SOURCE[1]} # this file's no is 0; the caller 1
			exit 0
		fi
	done
}


# IO
COLUMNS=${COLUMNS:=$(tput cols 2>/dev/null)} # set default line size
COLUMNS=${COLUMNS:=120} # set default line size
function prompt {
	local s
	if [ $# -ge 1 ]; then
		printf "====%s" "$*"
		s="$*"
		mylen=$(( COLUMNS - 4 - ${#s}))
		eval "printf '=%.0s' {1..$mylen}"
		printf '\n'
	fi
}

<<DOCUMENT
NAME
    draw_line - print one line in the terminal
SYNOPSIS
	draw_line              (1st form)
	draw_line char         (2nd form)
	draw_line char width   (3rd form)
DESCRIPTION
	In the lst form, print a line whose width equals the columns of xterm and whose 
    char is '='. In the 2nd from and 3rd form, the line's char is the the first 
	argument. In the 3rd, the line's width is the second argument. 
DOCUMENT
function draw_line {
	if [ $# -eq 2 ]; then
		if [[ $2 =~ ^[0-9]+$ ]]; then
			eval printf "'$1%.0s'" {1..$2}
		else  
			eval printf "'$1%.0s'" {1..$COLUMNS}
		fi
	elif [ $# -eq 1 ]; then
		eval printf "'$1%.0s'" {1..$COLUMNS}
	else
		eval printf "'=%.0s'" {1..$COLUMNS}
	fi
	printf '\n'
}
function towinpath_ {
	local v=$1
	[[ -L $v ]] && v=$(readlink $v)
	shopt -s nocasematch
	if [[ $v =~ ^(/cygdrive){0,1}/+([[:alpha:]])$ ]]; then
		v="${BASH_REMATCH[2]^}:/"
	elif [[ $v =~ ^(/cygdrive){0,1}/+([[:alpha:]])/+(.*)$ ]]; then
		v="${BASH_REMATCH[2]^}:/${BASH_REMATCH[3]}"
	elif [[ $v =~ ^/(.*)$ ]]; then
		v="C:/cygwin/${BASH_REMATCH[1]}"
	fi	
	shopt -u nocasematch
	v=${v//\//\\}
	echo "$v"
}

<<DOCUMENT
compare
	function gvim7 { local HOME="C:\vim"; local TMP=C:\tmp; cygstart /c/vim/vim74/gvim "$@"; }
	function gvim9 { local HOME="C:\\vim";                  cygstart /c/vim/vim90/gvim "$@"; }
DOCUMENT
function gvim7_ {
	local powershell='/cygdrive/c/windows/system32/WindowsPowerShell/v1.0/powershell' 
	local cmd='C:\vim\vim74\gvim'
	local params=()
	local TMP=C:\tmp #C:\Users\vic\AppData\Local\Temp      # we must use this; a bug?
	local HOME='C:\vim'
	local i
	for((i=1;i<=$#;i++)); do
		if [[ ${!i:0:1} == '-' ]]; then
			params+=("${!i}")
		elif [[ ${!i} =~ ^(scp|sftp): ]]; then
			params+=("${!i}")
		else
			local param=$(towinpath_ "${!i}")
			params+=("\"$param\"")
		fi
	done
	cygstart /c/vim/vim74/gvim  ${params[@]}
	#local cmdargs="${params[@]}" #$powershell start $cmd -ArgumentList "'$cmdargs'"
}
function gvim9_ {
	local HOME='C:\vim'
	local params=()
	local i
	local osname=$(uname)
	for((i=1;i<=$#;i++)); do
		if [[ ${!i:0:1} == '-' ]]; then
			params+=("${!i}")
		elif [[ ${!i} =~ ^(scp|sftp): ]]; then
			params+=("${!i}")
		else
			local param=$(cygpath -w "${!i}")
			if [[ $osname =~ ^MINGW ]]; then 
				params+=("$param")
			else # only cygwin
				params+=("\"$param\"")
			fi
		fi
	done
	cygstart /c/vim/vim90/gvim "${params[@]}"; 
}
function gvim_ { gvim9_ "$@"; }
function cutemarked_ { 
	local params=()
	local i
	local osname=$(uname)
	for((i=1;i<=$#;i++)); do
		if [[ ${!i:0:1} == '-' ]]; then
			params+=("${!i}")
		elif [[ ${!i} =~ ^(scp|sftp): ]]; then
			params+=("${!i}")
		else
			local param=$(cygpath -w "${!i}")
			if [[ $osname =~ ^MINGW ]]; then 
				params+=("$param")
			else # only cygwin
				params+=("\"$param\"")
			fi
		fi
	done
	cygstart /d/MyWinapp/CuteMarkdown/cutemarked "${params[@]}"; 
}
function mindforger_ { 
	local params=()
	local i
	local osname=$(uname)
	for((i=1;i<=$#;i++)); do
		if [[ ${!i:0:1} == '-' ]]; then
			params+=("${!i}")
		elif [[ ${!i} =~ ^(scp|sftp): ]]; then
			params+=("${!i}")
		else
			local param=$(cygpath -w "${!i}")
			if [[ $osname =~ ^MINGW ]]; then 
				params+=("$param")
			else # only cygwin
				params+=("\"$param\"")
			fi
		fi
	done
	cygstart /D/MyWinApp/MindForger/bin/mindforger "${params[@]}"; 
}
