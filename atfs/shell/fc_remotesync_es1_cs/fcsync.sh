#!/bin/bash

############################################
# @Name		ADHai FC Module
# @Ver		0.01
# @Author	Mac Chow
# @Email	zhouxinghai@adpanshi.com
############################################

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
	local ftype=$3
	local type=$4
	local nolocal="$5"
	if [ "${type:0:7}" = "archive" ]; then
		return
	fi
	if [ "$nolocal" != "nolocal" ]; then
		local result=`stat -c "%n,\`echo $2 | sed 's/%/\\\\%/g' \`,%s,%Y,\`date +%s\`,\`echo $ftype\`" $1`
	else
		local result=`remoteStat "$1" "$2" "$ftype"`
	fi
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

function checkFileRemote(){
	if [ "$AFTER_CHECK_FLAG" = "yes" ]; then
		local host=`echo $1 | awk -F ':' '{print $1}'`
		local path=`echo $1 | awk -F ':' '{print $2}'`
		local md5remote1=`ssh -p $REMOTE_PORT_NUM $host 'md5sum '$path' | awk "{print \\\$1}" '`
		logInfo "[$1] md5sum result: [$md5remote1]"
		local host=`echo $2 | awk -F ':' '{print $1}'`
		local path=`echo $2 | awk -F ':' '{print $2}'`
		local md5remote2=`ssh -p $TARGET_PORT_NUM $host 'md5sum '$path' | awk "{print \\\$1}" '`
		logInfo "[$2] md5sum result: [$md5remote2]"
		if [ "$md5remote1" = "$md5remote2" ]; then
			return 0
		else
			return 1
		fi
	else
		return 0
	fi
}

function checkFile(){
	if [ "$AFTER_CHECK_FLAG" = "yes" ]; then
		local host=`echo $2 | awk -F ':' '{print $1}'`
		local path=`echo $2 | awk -F ':' '{print $2}'`
		local md5local=`md5sum "$1" | awk '{print $1}'`
		logInfo "Local md5sum result: [$md5local]"
		local md5remote=`ssh -p $REMOTE_PORT_NUM $host 'md5sum '$path' | awk "{print \\\$1}" '`
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

function checkOpenFile(){
	if [ "$2" = "off" ]; then
		/usr/sbin/lsof "$1"
		if [ $? -eq 0 ];then
			return 1
		else 
			return 0
		fi
	elif [ "$2" = "on" ]; then
		remoteHost=`awkCut "$1" ":" 1`
		remotePath=`awkCut "$1" ":" 2`
		checkRemoteFileOpen $remoteHost $remotePath
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
	local target=`echo "$2" | sed 's/ /\\\\ /g'`
	local record
	local type=$3
	local needscp='yes'
	echo "$1" | grep -i ":"
	if [ $? -eq 0 ]; then
		local remoteMode="on"
		local remoteHost=`awkCut "$1" ":" 1`
		local remotePath=`awkCut "$1" ":" 2`
	else
		local remoteMode="off"
	fi
	echo "$2" | grep -i ":"
	if [ $? -eq 0 ]; then
		if [ "$remoteMode" = "on" ]; then
			local syncMode="on"
			local syncHost=`awkCut "$target" ":" 1`
			local syncPath=`awkCut "$target" ":" 1`
		fi
	else
		local syncMode="off"
	fi
	if [ "$type" != "temp" ]; then
		if [ "$remoteMode" = "off" ]; then
			record=`getRecord "$1" "$2"`
		elif [ "$remoteMode" = "on" ]; then
			record=`getRecord "$2" "$1"`
		fi
	fi
	if [ "$record" ]; then
		if [ $remoteMode = "on" ]; then
			if [ "$syncMode" = "on" ]; then
				local rsize=`remoteRun $syncHost "stat -c \"%s\" \"$syncPath\""`
				local rtime=`remoteRun $syncHost "stat -c \"%Y\" \"$syncPath\""`
				local size=`remoteRun $remoteHost "stat -c '%s' '$remotePath'"`
				local time=`remoteRun $remoteHost "stat -c '%Y' '$remotePath'"`
			else
				local rsize=`stat -c "%s" "$target"`
				local rtime=`stat -c "%Y" "$target"`
				local size=`remoteRun $remoteHost "stat -c '%s' '$remotePath'"`
				local time=`remoteRun $remoteHost "stat -c '%Y' '$remotePath'"`
			fi
		elif [ $remoteMode = "off" ]; then
			local rsize=`echo "$record" | awk -F ',' '{print $3}'`
			local rtime=`echo "$record" | awk -F ',' '{print $4}'`
			local size=`stat -c "%s" "$1"`
			local time=`stat -c "%Y" "$1"`
		fi
		if [ $rsize -eq $size ] && [ $rtime -eq $time ]; then
			needscp="no"
			logInfo "The latest [$1] has been already copied to [$2]."
		fi
	else
		needscp='yes'
	fi

	while [ "$needscp" = "yes" ]; do
		if [ $count -le $RETRY_IF_FAILED ]; then
			local countCheckOpen=1
			logInfo "Copying single file [$1] to [$2], times: [$count]"
			while [ $countCheckOpen -le $RETRY_IF_FILE_IS_OPENED ];do
				checkOpenFile "$1" "$remoteMode"
				if [ $? -eq 0 ]; then
					#if [ $syncMode = "on" ]; then   ###Modified
					if [ "$syncMode" = "on" ]; then
						ssh -p $REMOTE_PORT_NUM $remoteHost "scp -P $TARGET_PORT_NUM $remotePath $2"
					else
						scp -P $REMOTE_PORT_NUM "$1" "$target"
					fi
					status=$?
					break
				else
					logErr "[$1] file has been opened by some processes, time: [$countCheckOpen], retry in [$RETRY_IF_FILE_IS_OPENED_SLEEPTIME] seconds"
				fi
				countCheckOpen=`expr $countCheckOpen + 1`
				sleep $RETRY_IF_FILE_IS_OPENED_SLEEPTIME
			done
			if [ $status -eq 0 ]; then
				if [ $remoteMode = "on" ]; then
					if [ $syncMode = "on" ]; then
						checkFileRemote $1 $2
					else
						checkFile $2 $1
					fi
				else
					checkFile $1 $2
				fi
				if [ $? -eq 0 ]; then
					logInfo "[$1] copied success"
					if [ "$type" != "temp" ]; then
						if [ $remoteMode = "off" ]; then
							setRecord "$1" "$2" "$type" "normal"
						elif [ $remoteMode = "on" ]; then
							if [ $syncMode = "on" ]; then
								setRecord "$1" "$2" "$type" "normal" "nolocal"
							else
								setRecord "$2" "$1" "$type" "normal"
							fi
						fi
					fi
					break
				else
					logInfo "[$1] to [$2] copied success, but maybe has already been changed in source, will try next time"
					status=1
				fi
			else
				logErr "[$1] copied fail, retry"
			fi
		else
			logFail "[$1] to [$2], skip this file"
			#local fname=`basename "$1"`
			#cp "$1" "$FAILED_DIR/$fname`date '+_%Y-%m-%d-%H-%M-%S'`"
			break
		fi
		if [ $status -gt 0 ]; then
			sleep $RETRY_IF_FAILED_SLEEPTIME
		else
			break
		fi
		count=`expr $count + 1`
	done
	if [ $status -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

function sshMakeDir(){
	local status=1
	local count=1
	local host=`echo $2 | awk -F ':' '{print $1}'`
	local dir=`echo $2 | awk -F ':' '{print $2}'`
	local record=`getRecord "$1" "$2"`
	local needmkdir='yes'
	local nolocal="$4"
	echo "$1" | grep -i ":"
	if [ $? -eq 0 ]; then
		local remoteMode="on"
		local remoteHost=`awkCut "$1" ":" 1`
		local remotePath=`awkCut "$1" ":" 2`
	else
		local remoteMode="off"
		local remotePath="$1"
	fi
	if [ "$record" ]; then
		needmkdir="no"
		logInfo "The directory [$2$remotePath] has been already created."
	fi
	while [ $status -gt 0 ] && [ $needmkdir = "yes" ]; do
		if [ $count -le $RETRY_IF_FAILED ]; then
			logInfo "Make empty directory [$2$remotePath], times: [$count]"
			ssh -p $REMOTE_PORT_NUM $host "mkdir -p \"$dir$remotePath\""
			status=$?
			count=`expr $count + 1`
			if [ $status -eq 0 ]; then
				logInfo "[$2$remotePath] maked success"
				setRecord "$1" "$2" "dir" "normal" "$nolocal"
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

function makedir(){
	local dir=$1
	if [ -d $dir ]; then
		logInfo "The directory [$dir] has been already created."
	else
		logInfo "The directory [$dir] has been created successfully."
		mkdir -p "$dir"
	fi
}

function scpExtra(){
	local list=$1
	local remoteHost=$2
	local remotedir=$3
	local type=$4
	local defaultIFS=$IFS
	IFS=`echo -en "\n\b"`
	local item
	for item in $list; do
		if [ -f $item ]; then
			local fname=`basename "$item"`
			scpSingleFile "$item" "$remoteHost:$remotedir$item" "$type"
		elif [ -d $item ]; then
			sshMakeDir "$item" "$remoteHost:$remotedir" "$type"
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

function remoteRun(){
	local remoteHost=$1
	local command=$2
	returnstr=`ssh -p $REMOTE_PORT_NUM "$remoteHost" "$2"`
	local returncode=$?
	echo $returnstr
	return $returncode
}

function checkRemoteEnv(){
	local remoteHost=$1
	scpSingleFile "$LOCAL_SCRIPT_DIR/checkenv.sh" "$1:$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/checkenv.sh" "command"
	remoteRun "$remoteHost" "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/checkenv.sh"
	return $?
}

function generateFileList(){
	local remoteHost=$1
	local remotePath=$2
	local type=$3
	local mode=$4
	scpSingleFile "$LOCAL_SCRIPT_DIR/generatelist.sh" "$1:$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/generatelist.sh" "command"
	if [ "$type" = "direct" ]; then
		local list=`remoteRun "$remoteHost" "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/generatelist.sh \"$remotePath\" \"$type\" \"$mode\""`
		if [ $? -eq 0 ]; then
			echo -n $list
			return 0
		else
			logErr $list
			return 1
		fi
	elif [ ${type:0:5} = "regex" ]; then
		local list=`remoteRun "$remoteHost" "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/generatelist.sh \"$remotePath\" \"$type\" \"$mode\""`
		if [ $? -eq 0 ]; then
			echo -n $list
			return 0
		else
			logErr $list
			return 1
		fi
	elif [ ${type:0:6} = "script" ]; then
		local script=`awkCut "$type" ":" 2`
		scpSingleFile "$script" "$remoteHost:/tmp/`basename \"$script\"`" "command"
		type="script:"/tmp/`basename $script`
		local list=`remoteRun "$remoteHost" "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/generatelist.sh \"$remotePath\" \"$type\" \"$mode\""`
		if [ $? -eq 0 ]; then
			echo -n "$list"
			return 0
		else
			logErr $list
			return 1
		fi
	else
		logErr "Unknown type [$type]"
	fi
}

function scpCheckRemoteOpenScript(){
	local remoteHost=$1
	scpSingleFile "$LOCAL_SCRIPT_DIR/checkopen.sh" "$1:$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/checkopen.sh" "command"
}

function checkRemoteFileOpen(){
	local remoteHost=$1
	local remotePath=$2
	remoteRun $remoteHost "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/checkopen.sh \"$remotePath\"" 
	return $?
}

function remoteStat(){
	local remoteHost=`awkCut "$1" ":" 1`
	local remotePath=`awkCut "$1" ":" 2`
	local remotePath2="$2"
	local ftype="$3"
	local result=`remoteRun $remoteHost "$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/stat.sh \"$remotePath\" \"$remotePath2\" $ftype"`
	local code=$?
	echo $result
	return $code
}

function processCallback(){
	local remoteHost=`awkCut $2 "$5" 1`
	local remotePath=`awkCut $2 "$5" 2`
	local type=`awkCut $2 "$5" 3`
	local mode=`awkCut $2 "$5" 4`
	local targetHost=`awkCut $2 "$5" 5`
	local targetPath=`awkCut $2 "$5" 6`
	logInfo "Now processing: [$remoteHost:$remotePath], type:[$type], target: [$targetHost:$targetPath]"
	
	sshMakeDir "$LOCAL_SCRIPT_DIR" "$remoteHost:$REMOTE_SCRIPT_DIR/"

	checkRemoteEnv "$remoteHost"
	
	if [ $? -ne 0 ]; then
		logFail "Envrioment error: [$remoteHost]"
		return 1
	fi

	local list=`generateFileList "$remoteHost" "$remotePath" "$type" "$mode"`
	
	scpSingleFile "$LOCAL_SCRIPT_DIR/checkopen.sh" "$remoteHost:$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/checkopen.sh" "command"
	scpSingleFile "$LOCAL_SCRIPT_DIR/stat.sh" "$remoteHost:$REMOTE_SCRIPT_DIR/$LOCAL_SCRIPT_DIR/stat.sh" "command"
	
	defaultIFS=$IFS
	IFS=`echo -en "\n\b"`

	list=`echo -e "$list"|egrep '^[\[F\]|\[D\]]'`

	if [ "$MOVE_FLAG" = "yes" ]; then       
		if [ "$MOVE_TakeOrNot" = "yes" ]; then
			local jfdir
			ssh -p $REMOTE_PORT_NUM $remoteHost "test -e $remotePath"
			if [ $? -eq 0 ]; then   
				ssh -p $REMOTE_PORT_NUM $remoteHost "test -f $remotePath"
				if [ $? -eq 0 ]; then   
					lastpath=`dirname $remotePath`
					jfdir=`basename $lastpath`
				else                    
					jfdir=`basename $remotePath`
				fi
			else
				logErr "$remotePath not found,please check!"
			fi      
		else    
			jfdir=""
		fi      
		ssh -p $REMOTE_PORT_NUM $remoteHost "mkdir -p $SUCCESSED_DIR/$jfdir"
	fi              
	            
	local item
	
	ssh -p $REMOTE_PORT_NUM $remoteHost "test -f $remotePath"
	if [ $? -eq 0 -a "$type" = "direct" ]; then
		for item in $list;
		do
			rtype=`awkCut "$item" " " 1`
			item=`awkCut "$item" " " 2`
			echo "$item"
			local baseitem=`basename $item`
			scpSingleFile "$remoteHost:$item" "$targetHost:$targetPath/$baseitem" "command"
			if [ $? -eq 0 ]; then
				if [ "$MOVE_FLAG" = "yes" ]; then
					ssh -p $REMOTE_PORT_NUM $remoteHost "mv $item $SUCCESSED_DIR/$jfdir/$baseitem"
					if [ $? -eq 0 ]; then
						logInfo "Move $item to $SUCCESSED_DIR/$jfdir$baseitem success"
					else
						logInfo "Move $item to $SUCCESSED_DIR/$jfdir/$baseitem fail"
					fi
				fi
			fi
		done
	else
		for item in $list; do
			rtype=`awkCut "$item" " " 1`
			item=`awkCut "$item" " " 2`
			if [ "$rtype" = "[D]" -a "$item" != "$remotePath" ]; then
				local itemdirstr=`echo $item|sed "s#$remotePath\(.*\)#\1#"`
				ssh -p $TARGET_PORT_NUM $targetHost "mkdir -p $targetHost:$targetPath$itemdirstr"
				if [ "$MOVE_FLAG" = "yes" ]; then
					ssh -p $REMOTE_PORT_NUM $remoteHost "mkdir -p $SUCCESSED_DIR/$jfdir/$itemdirstr"
				fi
			fi
		done
		for item in $list; do
			rtype=`awkCut "$item" " " 1`
			item=`awkCut "$item" " " 2`
			if [ "$rtype" = "[F]" ]; then
				local itemfilestr=`echo $item|sed "s#$remotePath\(.*\)#\1#"`
				local itemdirname=`dirname $itemfilestr`
				local itemfilename=`basename $itemfilestr`
				scpSingleFile "$remoteHost:$item" "$targetHost:$targetPath$itemdirname/$itemfilename"
				if [ $? -eq 0 ]; then
					if [ "$MOVE_FLAG" = "yes" ]; then
						ssh -p $REMOTE_PORT_NUM $remoteHost "mv $item $SUCCESSED_DIR/$jfdir/$itemdirname/$itemfilename"
						if [ $? -eq 0 ]; then
							logInfo "Move $item to $SUCCESSED_DIR/$jfdir/$itemdirname/$itemfilename success"
						else
							logInfo "Move $item to $SUCCESSED_DIR/$jfdir/$itemdirname/$itemfilename fail"	
						fi
					fi
				fi
			elif [ "$rtype"  = "[D]" ]; then
				logInfo "Source itemi [dir] [$item] exist,it is ok."
			else
				logErr "Source item [$item] not exists, neither file or directory, skip."
			fi
		done
	fi
	logInfo "[$remoteHost:$remotePath] processed"
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
# if [ ! -d $FAILED_DIR ]; then
# 	mkdir -p "$FAILED_DIR"
# fi

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
