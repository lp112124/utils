
#生成文件

#!/bin/bash
#需要查询的文件及路径，格式：文件路径:文件名，多个查询，需要用空格符号隔开
#File_dir_name="/home/lfy/get_file/data:cs*.log /dsjld/dfd:dsf.tt"

Conf_dir="../conf"

Offset=0
Seq_num=1
S_file="base_info.dat"

#判断是否为第一次启动状态,第一次启动，YTD为当前日期 0000
function check_param()
{
	Date=$1
	Time=$2
	YTD="$Date""$Time"
	w_logs "1" "time is [$YTD]. [check_param]";
}

#写日志信息
function w_logs()
{
	local logs_info="INFO"
	if [ $1 -eq 1 ] ;then
		logs_info="INFO"
	elif [ $1 -eq 2 ] ;then
		logs_info="WARNING"
	fi
	if [ ! -d $Logs_dir ] ;then
		mkdir -p $Logs_dir
	fi
	echo "[`date "+%Y-%m-%d %H:%M:%S"`] [$logs_info] $2" >> $Logs_dir/build_file_$Date.log
}

function get_dir_name()
{
	local i
	for i in $File_dir_name
	do
		local file_dir=`echo "$i"|awk -F ':' '{print $1}'`
		local file_name=`echo "$i"|awk -F ':' '{print $2}'`
		w_logs "1" "Dir/file_name[$file_dir/$file_name]. [get_dir_name]";
		if [ ! -d $file_dir ] ;then
			w_logs "2" "Dir[$file_dir] does not exist. [get_dir_name]";
			continue;
		fi
		fwrite "$file_dir" "$file_name";
	done
}

function fwrite()
{
	local search_dir=$1
	local search_name=$2
	local num=0

	for i in $search_dir
	do
		num=0
		#cd $i
		touch -t $YTD $Logs_dir/tt
		w_logs "1" "YTD IS $YTD. [fwrite]"
		local file_name=`find $i -newer $Logs_dir/tt -name "$search_name"`
		rm $Logs_dir/tt
		file_name=("`echo ${file_name#//\n/ }`")
		if [ "-$file_name" == "-" ]; then
			w_logs "2" "file[$search_name]not exist. [fwrite]";
	#		continue;
		fi
		w_logs "1" "analyst Dir/filename[$file_name]. [fwrite]";

		local ret=0
		local search_file_num=0

		if [ ! -f $Base_file/$S_file ] ;then
			touch $Base_file/$S_file
		fi

		for j in $file_name
		do
			num=0
			#查询文件中是否还存在相同数据
			if [ -f $Base_file/$S_file ] ;then
				num=`grep "$j" $Base_file/$S_file |wc -l`
			fi
			if [ $num -eq 0 ] ;then
				w_logs "1" "file[$file_name] is new";
				echo "$Date $j $Offset $Seq_num 1" >> $Base_file/$S_file
			fi
			((search_file_num++))
		done
		
		while read LINE;
		do
			ret=0
			for j in $file_name
			do
				num=`echo "$LINE" |grep "$j" |wc -l`
				if [ $num -ne 0 ] ;then
					ret=1
					break;
				fi
			done
			if [ $ret -eq 0 -a $search_file_num -ge 1 ] ;then	#确保有两个文件生成
				w_logs "1" "info[$LINE] is over";
				local tmp_line=`echo $LINE|awk '{print $1" "$2" "$3" "$4" "0}'`
				sed -i "s#$LINE#$tmp_line#g" $Base_file/$S_file
			fi
		done < $Base_file/$S_file
	done
}

function get_conf()
{
	#cd $Conf_dir
	source $Conf_dir/split_file.conf
	Base_file=$base_dir
	Logs_dir=$log_path
}

get_conf;
check_param "$1" "$2";
w_logs "1" "====================startup script:[build_file.sh]===========================";
get_dir_name;
w_logs "1" "====================shutdown script:[build_file.sh]===========================";
