#!/bin/bash

#################################################
# @Name		ADHai FC Push Module Main Program
# @Ver		0.02
# @Author	Mac Chow
# @Email	zhouxinghai@adpanshi.com
#################################################

SCRIPT_PATH=`dirname $0`

cd $SCRIPT_PATH

source conf

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
		echo "[$1] has not been found in your path."
		exit 1
	fi
}

function getDate(){
	date "+%Y-%m-%d %H:%M:%S"
}

function logFail(){
	if [ $DEBUG = 'yes' ]; then
		set +x
	fi
	echo "[`getDate`] [FAIL] $*" >> $FAIL_LOG
	echo "[`getDate`] [FAIL] $*" >> $TOTAL_LOG
	if [ $DEBUG = 'yes' ]; then
		set -x
	fi
}

function logErr(){
	if [ $DEBUG = 'yes' ]; then
		set +x
	fi
 	echo "[`getDate`] [ERROR] $*" >> $ERROR_LOG
	echo "[`getDate`] [ERROR] $*" >> $TOTAL_LOG
	if [ $DEBUG = 'yes' ]; then
		set -x
	fi
}

function logInfo(){
	if [ $DEBUG = 'yes' ]; then
		set +x
	fi
	echo "[`getDate`] [INFO] $*" >> $INFO_LOG
	echo "[`getDate`] [INFO] $*" >> $TOTAL_LOG
	if [ $DEBUG = 'yes' ]; then
		set -x
	fi
}

function setRecord(){
	local type=$3
	#if [ ${type:0:7} = "archive" ]; then			
	if [ "${type:0:7}" = "archive" ]; then				##Modified
		return
	fi
	local result=`stat -c "%n,\`echo $2 | sed 's/%/\\\\%/g' \`,%s,%Y,\`date +%s\`,\`echo $4\`" $1`
	local now=`getRecord $1 $2`
	if [ "$now" ]; then
		local line=`echo "$now" | awk -F ':' '{print $1}'`
		result=`echo $result | sed 's/\//\\\\\//g'`
		sed -i "${line}s/.*/$result/" $PROCESS_CSV
	else
		echo $result >> $PROCESS_CSV
	fi
}

function getRecord(){
	local record=`grep -n "^$1,$2," $PROCESS_CSV`
	if [ "$record" ]; then
		echo $record
	fi
}

function checkFile(){
	if [ "$AFTER_CHECK_FLAG" = "yes" ]; then
		local host=`echo $2 | awk -F ':' '{print $1}'`
		local path=`echo $2 | awk -F ':' '{print $2}'`
		local md5local=`md5sum "$1" | awk '{print $1}'`
		logInfo "Local md5sum result: [$md5local]"
		local md5remote=`ssh -p $PORT_NUM $host 'md5sum '$path' | awk "{print \\\$1}" '`
		logInfo "Remote md5sum result: [$md5remote]"
		if [ "$md5local" = "$md5remote" ]; then
			return 0
		else
			return 1
		fi
	else
		return 0
	fi
}

function deleteFile(){
 	if [ "$DELETE_FLAG" = "yes" ]; then
 		rm -f $1
 	fi
}

function mvSuccessedFile(){				###Modified
 	if [ "$MOVE_FLAG" = "yes" ]; then
 		mv "$1" "$SUCCESSED_DIR"
 	fi
}

function checkOpenFile(){
	/usr/sbin/lsof $1
	if [ $? -eq 0 ];then
		return 1
	else 
		return 0
	fi
}

function csvParse(){
	local file=$1
	local delimiter=$2
	local callback=$3
	local content=`cat "$1"`
	local defaultIFS=$IFS
	IFS=`echo -en "\n\b"`
	local ln=0
	for i in $content; do
		ln=`expr $ln + 1`
		if [ ${i:0:1} = "#" ]; then
			continue
		fi
		local count=`echo $i | awk -F "$delimiter" '{print NF}'`
		#callback
		$callback "$file" "$i" "$ln" "$count" "$delimiter"
	done
	IFS=$defaultIFS
}

function awkCut(){
	local string=$1
	local delimiter=$2
	local idx=$3
	echo $string | awk -F "$delimiter" "{print \$$idx}"
}

function scpSingleFile(){
	local status=1
	local count=1
	local countCheckOpen=1
	local target=`echo "$2" | sed 's/ /\\\\ /g'`
	local record=`getRecord "$1" "$2"`
	local type=$3
	local needscp='yes'
	if [ "$record" ]; then
		local rsize=`echo "$record" | awk -F ',' '{print $3}'`
		local rtime=`echo "$record" | awk -F ',' '{print $4}'`
		local size=`stat -c "%s" "$1"`
		local time=`stat -c "%Y" "$1"`
		if [ $rsize -eq $size ] && [ $rtime -eq $time ]; then
			needscp="no"
			logInfo "The latest [$1] has been already copied to [$2]."
		fi
	else
		needscp='yes'
	fi
	while [ "$needscp" = "yes" ]; do
		if [ $count -le $RETRY_IF_FAILED ]; then
			logInfo "Copying single file [$1] to [$2], times: [$count]"
			while [ $countCheckOpen -le $RETRY_IF_FILE_IS_OPENED ];do
				checkOpenFile $1
				if [ $? -eq 0 ]; then
					scp -P $PORT_NUM -p "$1" "$target"
					status=$?
					break
				else
					logErr "[$1] file has been opened by some processes, time: [$countCheckOpen], retry in [$RETRY_IF_FILE_IS_OPENED_SLEEPTIME] seconds"
				fi
				countCheckOpen=`expr $countCheckOpen + 1`
				sleep $RETRY_IF_FILE_IS_OPENED_SLEEPTIME
			done
			countCheckOpen=1
			if [ $status -eq 0 ]; then
				checkFile $1 $2
				if [ $? -eq 0 ]; then
					logInfo "[$1] copied success"
					setRecord "$1" "$2" "$type" "file"
					mvSuccessedFile $1			###Modified
					deleteFile $1
					break
				else
					logInfo "[$1] to [$2] copied success, but maybe has already been changed in local system, will try next time"
					status=1
				fi
			else
				logErr "[$1] copied fail, retry"
			fi
		else
			logFail "[$1] to [$2], skip this file"
			local fname=`basename "$1"`
			cp "$1" "$FAILED_DIR/$fname`date '+_%Y-%m-%d-%H-%M-%S'`"
			break
		fi
		if [ $status -gt 0 ]; then
			sleep $RETRY_IF_FAILED_SLEEPTIME
		else
			break
		fi
		count=`expr $count + 1`
	done
}

function sshMakeDir(){
	local status=1
	local count=1
	local host=`echo $2 | awk -F ':' '{print $1}'`
	local dir=`echo $2 | awk -F ':' '{print $2}'`
	local record=`getRecord "$1" "$2"`
	local needmkdir='yes'
	if [ "$record" ]; then
		needmkdir="no"
		logInfo "The directory [$2$1] has been already created."
	fi
	while [ $status -gt 0 ] && [ $needmkdir = "yes" ]; do
		if [ $count -le $RETRY_IF_FAILED ]; then
			logInfo "Make empty directory [$2$1], times: [$count]"
			ssh -p $PORT_NUM $host "mkdir -p \"$dir$1\""
			status=$?
			count=`expr $count + 1`
			if [ $status -eq 0 ]; then
				logInfo "[$2$1] maked success"
				setRecord "$1" "$2" "$3" "dir"
				break
			else
				logErr "[$2] maked fail, retry"
				sleep $RETRY_IF_FAILED_SLEEPTIME
			fi
		else
			logFail "[$1] to [$2], skip this file"
			break
		fi
	done
}

function scpExtra(){
	local list=$1
	local remotehost=$2
	local remotedir=$3
	local type=$4
	local defaultIFS=$IFS
	IFS=`echo -en "\n\b"`
	local item
	for item in $list; do
		if [ -f $item ]; then
			local fname=`basename "$item"`
			scpSingleFile "$item" "$remotehost:$remotedir/$fname" "$type"			###Modified
		#	scpSingleFile "$item" "$remotehost:$remotedir$item" "$type"
		elif [ -d $item ]; then
			sshMakeDir $item "$remotehost:$remotedir" "$type"
		else
			logErr "Source item [$item] not exists, neither file or directory, skip."
		fi
	done
	IFS=$defaultIFS
}

function processTreeList(){
	local list=$1
	local newlist
	local item
	for item in $list; do
		if [ -f $item ]; then
			newlist=`echo "\`dirname $item\`\\n$item\\n$newlist\\n"`
		else
			newlist=`echo "$newlist\\\\n$item\\n"`
		fi
	done
	echo -e $newlist | awk '{print length($0),$0}' | sort -n | uniq | sed '/^[^ ]* /s///'
}

function processCallback(){
	local source=`awkCut $2 "$5" 1`
	local type=`awkCut $2 "$5" 2`
	local mode=`awkCut $2 "$5" 3`
	local remotehost=`awkCut $2 "$5" 4`
	local remotedir=`awkCut $2 "$5" 5`
	logInfo "Now processing: [$source], type:[$type], dest: [$remotehost:$remotedir]"
	if [ "$type" = "direct" ]; then
		if [ -f $source ]; then
			#local list=`echo -e "\`dirname $source\`\\n$source"`			###Modified
			local list=`echo -e "$source"`
		elif [ -d $source ]; then
			local list=`tree -afinN "$source" | sed '1d;$d'`
		else
			logErr "Source [$source] not exists, neither file or directory, skip. check [$1], line [$3]"
			break
		fi
		list=`sortListByDate "$list"`
		scpExtra "$list" "$remotehost" "$remotedir" "$type"
	elif [ ${type:0:5} = "regex" ]; then
		if [ -f $source ]; then
			logErr "Regex type only works in directory, check [$1], line [$3]";
			break
		elif [ -d $source ]; then
			local reg=`echo "$type" | awk -F ':' '{print $2}'`
			local list=`find "$source" -regex "$reg"`
			#list=`processTreeList "$list"`						###Modified
			list=`sortListByDate "$list"`
			scpExtra "$list" "$remotehost" "$remotedir" "$type"
		else
			logErr "Source [$source] not a directory, skip. check [$1], line [$3]"
		fi
	elif [ ${type:0:6} = "script" ]; then
		script=`echo "$type" | awk -F ':' '{print $2}'`
		list=`$script "$source"|sed "$d"`
		result=$?
		if [ $result -eq 0 ]; then
			logInfo "Script [$script] run ok"
			#list=`processTreeList "$list"`						###Modified
			list=`sortListByDate "$list"`
			scpExtra "$list" "$remotehost" "$remotedir"
		elif [ $result -eq 127 ]; then
			logErr "Script [$script] not exists, check [$1], line [$3]"
		else
			logErr "Script [$script] unknown error, check [$1], line [$3]"
		fi
	else
		logErr "Unknown type in [$1] @ line [$3]"
	fi
	echo -e "$list"
	logInfo "[$source] processed"
}

function sortListByDate(){
	local list=$1
	local tempfile="/tmp/list_for_sort_push_mc_cs.txt"
	> $tempfile
	local item
	for item in $list; do
		if [ -f $item ]; then
			#echo "`stat -c %Y "$item"` $item" >> $tempfile
			echo "`echo $item | cut -f3 -d_` $item" >> $tempfile
		fi
	done
	list=`sort -n "$tempfile" | sed -e 's/[^ ]* //'`
	for item in $list; do
		echo $item
	done
}

function makeArchive(){
	local tarFile="/tmp/`basename $1``date '+_%Y-%m-%d-%H-%M-%S'`.tar.gz"
	logInfo "Making archive: [$1] into [$tarFile]"
	tar -czf $tarFile $1 > /dev/null
	logInfo "Archive maked: [$tarFile]"
	echo $tarFile
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

# Debug flag
if [ $DEBUG = "yes" ]; then
	export PS4='. $0.$LINENO  '
	set -x
fi

logInfo "[$0] is running now, PID:[$$], current directory: [`pwd`]"

echo "$$" > pid

# Check lock file
if [ -f $LOCK_FLAG ]; then
	logInfo "[$LOCK_FLAG] with exists, PID [`cat $LOCK_FLAG`]"
	logInfo "Stop running"
	exit 1
else
	echo $$ > $LOCK_FLAG
fi

# Create files and dirs
if [ ! -f $PROCESS_CSV ]; then
	> $PROCESS_CSV
fi
if [ ! -d $FAILED_DIR ]; then
	mkdir -p "$FAILED_DIR"
fi
if [ ! -d $SUCCESSED_DIR ]; then			###Modified
	mkdir -p "$SUCCESSED_DIR"
fi

logInfo "Run mode: [$RUN_MODE]"

# Main loop
if [ $RUN_MODE = "onetime" ]; then
	csvParse $FILES "," "processCallback"
elif [ $RUN_MODE = "repeat" ]; then
	echo "" > $ABORT_FLAG
	STOPFLAG=""
	while [ "$STOPFLAG" != "abort" ]; do
		csvParse $FILES "," "processCallback"
		sleep $RUN_INTERVAL
		STOPFLAG=`cat $ABORT_FLAG`
	done
fi

# Clean quit
rm $LOCK_FLAG
logInfo "[$0] is exiting now, PID:[$$]"

if [ "$DEBUG" = "yes" ]; then
	set +x
fi
