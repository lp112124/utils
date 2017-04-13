#/bin/bash

function checkCommand(){
	flag=1
	defaultIFS=$IFS
	IFS=":"
	for path in $PATH; do
		if [ -f "$path/$1" ]; then
			flag=0
			break
		fi
	done
	IFS=$defaultIFS
	if [ $flag -ne 0 ]; then
		echo "[$1] has not been found in your [$1] path."
		exit 1
	fi
}

# Check Enviroment
checkCommand 'ssh'
checkCommand 'scp'
checkCommand 'stat'
checkCommand 'awk'
checkCommand 'sed'
checkCommand 'tar'
checkCommand 'md5sum'
checkCommand 'dirname'
checkCommand 'basename'
checkCommand "tree"
checkCommand "find"
checkCommand "grep"
checkCommand "sort"
checkCommand "uniq"

exit 0