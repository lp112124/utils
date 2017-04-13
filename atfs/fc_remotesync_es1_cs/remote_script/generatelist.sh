#!/bin/bash

source=$1
type=$2
mode=$3
list=""

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

if [ "$type" = "direct" ]; then
	if [ -f $source ]; then
		#list=`echo -e "\`dirname $source\`\\n$source"`
		list=`echo -e "$source"`		###Modified
	elif [ -d $source ]; then
		#list=`tree -afinN "$source" | sed '$d'`
		list=`tree -afinN "$source" | sed '1d;$d'`			###Modified
	else
		echo "Source [$source] not exists, neither file or directory, skip. check your configure."
		exit 1
	fi
elif [ ${type:0:5} = "regex" ]; then
	if [ -f $source ]; then
		echo "Regex type only works in directory";
		exit 1
	elif [ -d $source ]; then
		reg=`echo "$type" | awk -F ':' '{print $2}'`
		list=`find "$source" -regex "$reg"`
	#	list=`processTreeList "$list"`				###Modified
	else
		echo "Source [$source] not a directory, skip."
		exit 1
	fi
elif [ ${type:0:6} = "script" ]; then
	script=`echo "$type" | awk -F ':' '{print $2}'`
	list=`$script "$source"`
	result=$?
	if [ $result -eq 0 ]; then
		list=`processTreeList "$list"`				###Modified
#		echo "Script [$script] run ok"
	elif [ $result -eq 127 ]; then
		echo "Script [$script] not exists, please check"
		exit 1
	else
		echo "Script [$script] unknown error, please check"
		exit 1
	fi
fi


# sort by file last modification time
tempfile="/tmp/list_for_sort_es1_cs.txt"
> $tempfile
for item in $list; do
	if [ -f $item ]; then
		echo "`stat -c %Y "$item"` $item" >> $tempfile
	fi
done
list=`sort -n "$tempfile" | sed -e 's/[^ ]* //'`




defaultIFS=$IFS
IFS=`echo -en "\n\b"`
result=""

for item in $list; do
#	if [ -f "$source" ]; then		###Modified
#		source=`dirname $source`	###
#	fi					###
#	prefix=`echo $source | sed -r "s/\//\\\\\\\\\//g"`
#	itemstr=`echo $item | sed s/^$prefix//g`
	if [ -f $item ]; then
		result="$result\\n[F] $item"
	elif [ -d $item ]; then
		result="$result\\n[D] $item"
	fi
done


echo -n "$result"
IFS=$defaultIFS

exit 0
