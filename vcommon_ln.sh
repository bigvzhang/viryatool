#!/bin/bash
<<DOCUMENT
functions
   ln_one_file_       : not parse parameters
   ln_one_file_hard   : parse parameters; as an independant command
   ln_one_file_symbl  : parse parameters; as an independant command
DOCUMENT
function resolve_conflict_ {
	# $action_to_resolve - 1:pull, 2:push, 0:none
	local rtn
	local file1=$1
	local file2=$2
	local time1; time1=$(stat -c %y "$file1") || return 1
	local time2; time2=$(stat -c %y "$file2") || return 1
	time1=${time1:0:19}
	time2=${time2:0:19}
	if [[ "$time1" > "$time2" ]]; then
		pstr="$file1[$time1] gt [$time2] (1:pull<-|2:push->|0:none)? " 
	elif [[ "$time1" < "$time2" ]]; then
		local dft_action=1
		pstr="$file1[$time1] lt [$time2] (1:pull<-|2:push->|0:none)? "
	else
		pstr="$file1[$time1] == [$time2] (1:pull<-|2:push->|0:none)? "
	fi
	if [[ $opt_force == "I" && $action_to_resolve =~ ^[012]$ ]]; then
		case ${action_to_resolve} in
		1) ln -f "$file2" "$file1"; rtn=$?; echo "$pstr (pull:$rtn)" ;; # pull
		2) ln -f "$file1" "$file2"; rtn=$?; echo "$pstr (push:$rtn)" ;; # push
		0) echo "$pstr skipped";    rtn=0                            ;; # skip
		esac
		return $rtn
	fi
	while [[ 1 -eq 1 ]];do 
		read -t 180 -p "$pstr" action_to_resolve || abort "Timeout, aborted!"
		case ${action_to_resolve} in
		1) ln -f "$file2" "$file1"; rtn=$?; break ;; # pull
		2) ln -f "$file1" "$file2"; rtn=$?; break ;; # push
		0)                          rtn=0;  break ;; # skip	
		*)                                        ;; #continue
		esac
	done
	return $rtn
}
# global variables:
#    opt_force: [0:1]
#    action:    [create,validate,rm]
function ln_one_file_ { # link a file; the performance better than ln_one_file_hard
	# $1 = Src Dir
	# $2 = Dest Dir 
	# $3 = Filename
	# $4 = Filename2
	# $5 = inode of source file
	if [ $# -lt 4 ]; then
		return 1
	fi
	local vSRC=$1
	local vDEST=$2
	local vFILE=$3
	local vFILE2=$4
	local vID1
	local vID2
	if [[ -n $5 ]]; then
		vID1=$5
	else
		vID1=$(ls -i $vSRC/$vFILE) || return 1
	fi
	if [ ! -d $vDEST ]; then       # create dest dir
		if ! mkdir -p $vDEST; then
			return 1               # return if failed
		fi
	fi
	if [ "$action" == "validate" ]; then
		if [ -f $vDEST/$vFILE2 ]; then
			vID2=$(ls -i $vDEST/$vFILE2)
			if [ ${vID1%% *} == ${vID2%% *} ]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
			fi
		else
			echo "!$vFILE2 NOT in $vDEST"
		fi
	elif [ "$action" == "rm" ]; then
		if rm "$vDEST/$vFILE2";  then
			echo " linkfile $vDEST/$vFILE2 is removed"
		else
			echo " linkfile $vDEST/$vFILE2 NOT removed!"
		fi
	else                                # create
		if [ -f $vDEST/$vFILE2 ]; then
			vID2=$(ls -i "$vDEST/$vFILE2")
			if [[ ${vID1%% *} == ${vID2%% *} ]]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			elif [[ "$opt_force" == "1" ]]; then
				if ln -f $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
					echo "$vSRC/$vFILE ==> $vDEST/$vFILE2"
				else
					echo "!!!Cannot create hardlink $vDEST/$vFILE2 for $vSRC/$vFILE"
					return 1
				fi
			elif [[ "$opt_force" =~ ^[iI]$ ]]; then
				resolve_conflict_ "$vSRC/$vFILE" "$vDEST/$vFILE2"
			elif [[ "$opt_force" =~ ^d$ ]]; then
				gvim_ -d "$vSRC/$vFILE" "$vDEST/$vFILE2"
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
			fi
		else
			if ln $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
				echo "$vSRC/$vFILE ==> $vDEST/$vFILE2"
			else
				echo "!!!Cannot create hardlink $vDEST/$vFILE2 for $vSRC/$vFILE"
				return 1
			fi
		fi
	fi
}

function ln_one_file_symbl {
	# $1 = Src Dir
	# $2 = Dest Dir 
	# $3 = Filename
    # $4 = Filename2
    # --force
    # --create
    # --rm
    # --validate
	local action=validate	
	local vRSC
	local vDEST
	local vFILE
	local vFILE2
	local vID1
	local vID2
	local opt_force=0
	local items=()
	local i
	local arg
	for ((i=1; i<=$#; i++)); do
		arg=${!i}
		case $arg in
	    --force)    opt_force=1      ;;
	    --create)   action=create    ;;
	    --rm)       action=rm        ;;
	    --validate) action=validate  ;;
		*)  if [[ ${arg:0:1} == '-' ]]; then
				return 1
			else
				items+=("${!i}") 
			fi
			;;
		esac
	done
	if [ ${#items[@]} -lt 2 ]; then
		return  1
	fi
	if [[ ${#items[@]} -eq 2 ]]; then
		[[ -f ${items[0]} ]] || return 1 # the first must be a regular file
		vSRC=$(dirname "${items[0]}")
		vFILE=$(basename "${items[0]}")
		if [[ -d "${items[1]}" ]]; then
			vDEST="${items[1]}"
			vFILE2=$vFILE
		else
			vDEST=$(dirname "${items[1]}")
			[[ -d $vDEST ]] || return 1 # the directory must be there
			vFILE2=$(basename "${items[1]}")
		fi
	else                        
		vSRC="${items[0]}"
		vDEST="${items[1]}"
		vFILE="${items[2]}"
		case ${#items[@]} in
		3) vFILE2=$vFILE         ;; # src dst fname
		4) vFILE2="${items[2]}"  ;; # src dst fname linkname
		*) return  1             ;;	
		esac
	fi

	if [ ! -d $vDEST ]; then       # create dest dir
		if ! mkdir -p $vDEST; then
			return 1               # return if failed
		fi
	fi
	if [ "$action" == "validate" ]; then
		if [ -L $vDEST/$vFILE ]; then
			vID1=$(ls -iL $vSRC/$vFILE)
			vID2=$(ls -iL $vDEST/$vFILE2)
			if [ ${vID1%% *} == ${vID2%% *} ]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
				return 1
			fi
		else
			echo "!$vFILE NOT in $vDEST"
			return 1
		fi
	elif [ "$action" == "rm" ]; then
		if rm "$vDEST/$vFILE2";  then
			echo " linkfile $vDEST/$vFILE2 is removed"
		else
			echo " linkfile $vDEST/$vFILE2 NOT removed!"
			return 1
		fi
	else
		if [ -L $vDEST/$vFILE2 ]; then
			vID1=$(ls -iL $vSRC/$vFILE     2>/dev/null) || vID1="" # not necessary to set vID again
			vID2=$(ls -iL "$vDEST/$vFILE2" 2>/dev/null) || vID2="" # not necessary to set vID again
			if [[ ${vID1%% *} == ${vID2%% *} ]]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			elif [[ "$opt_force" == "1" ]]; then
				if ln -sf $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
					echo "$vSRC/$vFILE ==> $vDEST/$vFILE2"
				else
					echo "Cannot create symbol link $vDEST/$vFILE2 for $vSRC/$vFILE"
					return 1
				fi
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
				return 1
			fi
		else
			if ln -s $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
				echo "$vSRC/$vFILE => $vDEST/$vFILE2"
			else
				echo "Cannot create symbol link $vDEST/$vFILE2 <- $vSRC/$vFILE"
				return 1
			fi
		fi
	fi
}


function ln_one_file_hard {
	# $1 = Src Dir
	# $2 = Dest Dir 
	# $3 = Filename
    # $4 = Filename2
    # --force
    # --create
    # --rm
    # --validate
	local action=validate	
	local vRSC
	local vDEST
	local vFILE
	local vFILE2
	local vID1
	local vID2
	local opt_force=0
	local items=()
	local i
	local arg
	for ((i=1; i<=$#; i++)); do
		arg=${!i}
		case $arg in
	    --force)    opt_force=1      ;;
	    --create)   action=create    ;;
	    --rm)       action=rm        ;;
	    --validate) action=validate  ;;
		*)  if [[ ${arg:0:1} == '-' ]]; then
				return 1
			else
				items+=("${!i}") 
			fi
			;;
		esac
	done
	if [ ${#items[@]} -lt 2 ]; then
		return  1
	fi
	if [[ ${#items[@]} -eq 2 ]]; then
		[[ -f ${items[0]} ]] || return 1 # the first must be a regular file
		vSRC=$(dirname "${items[0]}")
		vFILE=$(basename "${items[0]}")
		if [[ -d "${items[1]}" ]]; then
			vDEST="${items[1]}"
			vFILE2=$vFILE
		else
			vDEST=$(dirname "${items[1]}")
			[[ -d $vDEST ]] || return 1 # the directory must be there
			vFILE2=$(basename "${items[1]}")
		fi
	else                        
		vSRC="${items[0]}"
		vDEST="${items[1]}"
		vFILE="${items[2]}"
		case ${#items[@]} in
		3) vFILE2=$vFILE         ;; # src dst fname
		4) vFILE2="${items[2]}"  ;; # src dst fname linkname
		*) return  1             ;;	
		esac
	fi

	if [ ! -d $vDEST ]; then       # create dest dir
		if ! mkdir -p $vDEST; then
			return 1               # return if failed
		fi
	fi
	if [ "$action" == "validate" ]; then
		if [ -L $vDEST/$vFILE ]; then
			vID1=$(ls -i $vSRC/$vFILE)
			vID2=$(ls -i $vDEST/$vFILE2)
			if [ ${vID1%% *} == ${vID2%% *} ]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
				return 1
			fi
		else
			echo "!$vFILE NOT in $vDEST"
			return 1
		fi
	elif [ "$action" == "rm" ]; then
		if rm "$vDEST/$vFILE2";  then
			echo " linkfile $vDEST/$vFILE2 is removed"
		else
			echo " linkfile $vDEST/$vFILE2 NOT removed!"
			return 1
		fi
	else # create
		if [ -f $vDEST/$vFILE2 ]; then
			vID1=$(ls -i $vSRC/$vFILE)
			vID2=$(ls -i "$vDEST/$vFILE2")
			if [ ${vID1%% *} == ${vID2%% *} ]; then
				echo "$vSRC/$vFILE === $vDEST/$vFILE2"
			elif [ "$opt_force" == "1" ]; then
				if ln -f $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
					echo "$vSRC/$vFILE ==> $vDEST/$vFILE2"
				else
					echo "!!!Cannot create hard link $vDEST/$vFILE2 for $vSRC/$vFILE"
					return 1
				fi
			else
				echo "$vSRC/$vFILE != $vDEST/$vFILE2"
				return 1
			fi
		else
			if ln $vSRC/$vFILE $vDEST/$vFILE2 2>/dev/null; then
				echo "$vSRC/$vFILE => $vDEST/$vFILE2"
			else
				echo "!!!Cannot create hard link $vDEST/$vFILE2 for $vSRC/$vFILE"
				return 1
			fi
		fi
	fi
}

function ln_one_dir { # only one level
	# $1 = Src Dir
	# $2 = Dest Dir
	# $3 = PATTERN
    #  $4 = pattern to replace
    #  $5 = replacement
    # examples: 
    #          d1 d2 *.sh test[[:digit:]]*_
    #          d1 d2 *.sh test[[:digit:]]*_ xxx
	if [ $# -lt 2 ]; then
		return 1 
	fi
	local PATTERN; [[ -z $3 ]] || PATTERN="^${3//\*/\.\*}\$"
	local PATTERN2=$4
	local REPLACEMENT=$5
	local lines=()
	local line
	local f
	local id1
	local file1
	local i
	while read f; do lines+=("$f"); done< <(ls -li $1)
	for((i=0; i < ${#lines[@]}; i++));  do
		# match the pattern, and the vFILE is normal
		if [[ ${lines[i]} =~ ^([[:digit:]]+)[[:space:]]+-.+[[:space:]]+(.+)$ ]]; then
			id1=${BASH_REMATCH[1]}
			file1=${BASH_REMATCH[2]}
			if [ -z "$PATTERN" ]; then
				ln_one_file_ $1 $2 $file1 $file1 $id1
			else
				if [[ $file1 =~ $PATTERN ]]; then
					if [[ -z "$PATTERN2" ]]; then
						ln_one_file_ $1 $2 $file1 $file1 $id1
					else
					    ln_one_file_ $1 $2 $file1 "${file1/$PATTERN2/$REPLACEMENT}" $id1
					fi
				fi
			fi
		fi
	done
}

function ln_one_dir__r { # recursively
	# $1 = Src Dir
	# $2 = Dest Dir
	# $3 = PATTERN
	if [ $# -ne 2 ]; then
		return 1
	fi
	local PATTERN; [[ -z $3 ]] || PATTERN="^${3//\*/\.\*}\$"
	local files=()
	local ids=()
	local id1
	local f
	local i
	local src1
	local file1
	local dest
	local subdir
	while read id1 f; do files+=("$f"); ids+=($id1); done < <(find $1 -type f -ls | awk '{print $1" "$NF}')
	for((i=0; i < ${#ids[@]}; i++)); do
		f=${files[i]}
		id1=${ids[i]}
		# match the pattern, and the vFILE is normal
		src1=$(dirname $f)
		file1=$(basename $f)
		if [ ${src1} == ${1} ]; then
			dest=$2
		else
			local subdir=${src1:${#1}}
			if [[ ${subdir} =~ \/(\..*|CVS|SVN)(\/|$) ]]; then # exclude hidden, CVS & ...
				continue	
			fi
			subdir=${subdir#/}
			dest=$2/$subdir
		fi
		if [ -z "$PATTERN" ]; then
			ln_one_file_ $src1 $dest $file1 $file1 $id1
		else
			if [[ $file1 =~ $PATTERN ]]; then
				ln_one_file_ $src1 $dest $file1 $file1 $id1
			fi
		fi
	done
}

function cmp_one_file {
	# $1 = Src Dir
	# $2 = Dest Dir 
	# $3 = Filename
	# $4 = inode of source file
	if ! [ $# -eq 3 -o $# -eq 4 -o $# -eq 5 ]; then
		echo "!Function(cmp_one_file) required 4 or 5 parameters!"
		return 1 
	fi
	vSRC=$1
	vDEST=$2
	vFILE=$3
	if ! [[ -z $4 ]]; then
		vID1=$4
	else
		vID1=$(ls -i $vSRC/$vFILE)
		if [[ -z $vID1 ]]; then
			echo "File($vSRC/$vFILE) doesn't exist!"
			return
		fi
	fi
	if [ $# -eq 5 ]; then
		vPrint=$5
	else
		vPrint='0'
	fi
	if [ ! -d $vDEST ]; then 
		[[ $vPrint == "1" ]] && echo "!Dir($vDEST) NOT exist!"
		return 1               # return if failed
	elif [ -f "$vDEST/$vFILE" ]; then
		vID2=$(ls -i "$vDEST/$vFILE")
		if [ ${vID1%% *} == ${vID2%% *} ]; then
			[[ $vPrint == "1" ]] && printf "%-30s === %-30s\n" "$vFILE" "$vFILE"
			return 0
		else
			if diff "$vSRC/$vFILE" "$vDEST/$vFILE" 2>/dev/null 1>&2; then
				[[ $vPrint == "1" ]] && printf "%-30s ==  %-30s\n" "$vFILE" "$vFILE"
				return 0
			else
				[[ $vPrint == "1" ]] && printf "%-30s !=  %-30s\n" "$vFILE" "$vFILE"
				return 1
			fi
		fi
	else
		[[ $vPrint == "1" ]] && printf "%-30s !x! \n" "$vFILE"
		return 1
	fi
}

function cmp_one_dir {
	# $1 = Src Dir
	# $2 = Dest Dir
	# $3 = print?
	if ! [ $# -eq 2 -o $# -eq 3 ]; then
		return 1 
	fi
	error=0
	while read f; do
		# match the pattern, and the vFILE is normal
		if [[ $f =~ ^([[:digit:]]+)[[:space:]]+(.+)$ ]]; then
			id1=${BASH_REMATCH[1]}
			file1=${BASH_REMATCH[2]##*/}
			if [ -z "$PATTERN" ]; then
				cmp_one_file $1 $2 "$file1" $id1 $3 || ((error++))
			else
				if [[ $file1 =~ $PATTERN ]]; then
					cmp_one_file $1 $2 "$file1" $id1 $3 || ((error++))
				fi
			fi
		fi
	done < <(find $1 -maxdepth 1 -type f -exec ls -i \{\} \;)
	if [ $error -gt 0 ]; then
		return 1
	else
		return 0
	fi
}
