#ams日终

#!/bin/bash

####全局变量####
Y_date=`date -d "-1 day"  "+%Y%m%d"`
N_date=`date -d "-0 day"  "+%Y%m%d"`
#程序记录
conf_dir="/data2/ADMS/gather/e4d/conf/monit_ams.conf"
#conf_dir="/tmp/test/monit_ams.conf"
####
############################基础信息#################################
#判断参数，是默认还是设定
function check_time()
{
	if [ "-$1" = "-" ] ;then
		Y_date=`date -d "-1 day"  "+%Y%m%d"`
		N_date=`date -d "-0 day"  "+%Y%m%d"`
	else
		Y_date=$1
		N_date=$(($1+1))
	fi
}

#读取ams的配置文件
function get_ams_conf()
{
	kz_file_path=`cat $ams_conf|grep "kz_file_path"|awk -F '=' '{print $2}'`
	history_file_path=`cat $ams_conf|grep "history_file_path"|awk -F '=' '{print $2}'`
	latest_time="`date -d "$N_date" "+%Y-%m-%d "`""$latest"
}

#得到日期时间
function get_date()
{
	monitor_time=`date "+%Y-%m-%d %H:%M:%S"`
}


#获取监控脚本的配置文件
function get_monit_conf()
{
	source $conf_dir
}

#获取服务器信息ip与名称
function get_server_info()
{
	host_name=`cat /proc/sys/kernel/hostname`
	eth_num=`find /etc/sysconfig/network-scripts -name "ifcfg-eth*"|wc -l`
	for((i=0; i<$eth_num; i++))
	do
		onboot=`grep "ONBOOT" /etc/sysconfig/network-scripts/ifcfg-eth$i|awk '{if($0 ~ /ONBOOT=yes/) {print "yes"} else {print "no"}}'`
		if [ "$onboot" == "yes" ] ;then
			host_ip=`grep "IPADDR" /etc/sysconfig/network-scripts/ifcfg-eth$i|awk -F '=' '{print $2}'`
			break;
		fi
	done
}

#写日志信息,$1:输入类型（1追加或2修改），$2:输入信息,$3路径+文件名;若只有2个参数，就只输入信息
function w_logs()
{
	sleep 1s;
	if(($1 == 1)) ;then
		echo "$2">>$3
	elif(($1 == 2)) ;then
		echo "$2">$3
	else
		echo "[`date "+%Y-%m-%d %H:%M:%S"`] [INFO] $2" >> $logs_dir/mt_ams_$N_date.log
	fi
}

#获取时间之差
function get_dif_time()
{
	ctime=`date "+%Y-%m-%d %H:%M:%S"`
#       ctime=`date -d "$N_date"  "+%Y-%m-%d %H:%M:%S"`
	temp_t1=`date -d "$1" +%s`
	temp_t2=`date -d "$ctime" +%s`
	dif_time=$(($temp_t2 - $temp_t1))
}

#获取自增num：$1：输入的数据1,2,3
function get_sequence()
{
	temp_num1=$((`echo $1|awk '{print length($0)}'` + 1))
	temp_num2=`echo $sequence_init|awk '{print substr($0,'"$temp_num1"')}'`
	sequence_num="$temp_num2""$1"
}

function subtime()
{
	w_logs "3" "ent subtime";
	time1=`date -d "$1" +%s`
	time2=`date -d "$2" +%s`
	
	w_logs "3" "time1[$time1]	time2[$time2]"
	sub_time=$(($time1-$time2))
	w_logs "3" "over subtime	sub_time[$sub_time]";
}


#设置自增编号
function set_add_num()
{
	get_monit_conf; 
	w_logs "3" "ent set_add_num";
	if [ "-$now_date" = "-" ] ;then
		echo "now_date=$N_date" >>$conf_dir
		sed -i 's/Add_num.*/Add_num=1/g' $conf_dir
	elif [ $N_date -ne $now_date ] ;then
		sed -i 's/Add_num.*/Add_num=1/g' $conf_dir
		sed -i 's/now_date.*/now_date='"$N_date"'/g' $conf_dir
	fi
	w_logs "3" "over set_add_num";
}



#数据是否已经存在 $1:比较的key1 返回值：0：存在 1：不存在
function info_exist()
{
	w_logs "3" "ent info_exist";
	key1=$1

	if [ "_$key1" != "_$temp_key" ] ;then
		w_logs "3" "本次插入的数据在文件中不存在，上次插入的key是[$temp_key],这次插入的key是[$key1]";
		temp_key=$key1
		return 1
	fi
	w_logs "3" "数据已经在文件中存在";
	return 0
}

####

###############################功能实现########################
#检查batch是否正确
function check_batch_num()
{
#获取batch路径:/data1/batch_logs/history/2012-06-14
	local batch_current_dir="$kz_file_path"
	local batch_history_dir="$history_file_path"

	w_logs "3" "old_batch_history_dir=[$batch_history_dir];batch_current_dir=[$batch_current_dir]";
	
	local batch_array=($batch_logs)
	batch_length=${#batch_array[*]}
	local batch_num=0
	local batch_num1=0

	for((i=0; i<$batch_length; i++))
	do
		#当current目录下无，则到history下寻找
		if [ ! -f $batch_current_dir/${batch_array[$i]} ] ;then
			ctime=`date -d "$N_date"  "+%Y-%m-%d"`
			w_logs "3" "$ctime $history_file_path";
			
			batch_history_dir=`find $history_file_path -name "$ctime" |sort -r|sed -n 1p`
			w_logs "3" "new_batch_history_dir=$batch_history_dir";

			if [ "-$batch_history_dir" = "-" -o ! -f $batch_history_dir/${batch_array[$i]} ] ;then
				w_logs "3" "在路径$batch_history_dir下木有这个文件${batch_array[$i]}";
			else
				w_logs "3" "文件${batch_array[$i]},在路径$batch_history_dir下";
				((batch_num1++))
			fi
		else
			w_logs "3" "文件${batch_array[$i]},在路径$batch_current_dir下";
			((batch_num++))
		fi
	done

	if(($batch_num1 == $batch_length)) ;then
		batch_num=0
	elif(($(($batch_num1+$batch_num)) == $batch_length)) ;then
		batch_num=$batch_length
	else
		batch_num=$(($batch_length+1))
	fi

	return $batch_num
}

#batch文件是否收到，且数量是否正确,返回值，0：快照加载成功，1：开始加载快照，2：快照还未传过来，3：其他未知原因(快照数量错误)
function mount_batch()
{
	check_batch_num;
	local batch_num_ok=$?

	if(($batch_num_ok == $batch_length)) ;then
		return 1
	elif(($batch_num_ok == $(($batch_length+1)))) ;then
		return 2
	elif(($batch_num_ok == 0)) ;then
		return 0
	else
		w_logs "3" "未知状态";
		return 3
	fi

}


#####
##########################################最终实现
#main
function main()
{
	key=""
	set_add_num;
	get_monit_conf;
	check_time "$1";
	get_server_info;

#暂时添加
	if [ ! -d $monit_file_dir ] ;then
		mkdir $monit_file_dir
	fi
       
	add_num=$Add_num
	sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
	get_sequence "$add_num";

	flow_node="$load_batch_log"
	status="$N"
	desc="load_batch_log"

	start_time=`date "+%Y-%m-%d %H:%M:%S"`
	end_time=`date "+%Y-%m-%d %H:%M:%S"`
	temp_time=`date "+%Y%m%d%H%M%S"`
	monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"
	local jump_flag=0
	
	process_time=`date "+%Y-%m-%d %H:%M:%S"`
	get_date;
	temp_key="$flow_node""$status"

	msg="$table_name&$monitor_time|$process_time|$service_id|$machine_type|$host_ip|$host_name|$flow_node|$status|$desc|$add_num"
	w_logs "1" "$msg" "$tmp_dir/$monit_file_name";

	while [ 1 ]
	do
		process_time=`date "+%Y-%m-%d %H:%M:%S"`
		get_date;
		get_ams_conf;
		mount_batch;
		batch_flags=$?
		
		#返回值，0：快照加载成功，1：开始加载快照，2：快照还未传过来，3：其他未知原因
		if(($batch_flags == 0)) ;then
			w_logs "3" "快照加载成功";
			status="$S"
			jump_flag=1
	
		elif(($batch_flags == 2)) ;then
			w_logs "3" "还未收到快照";
			status="$N"
		elif(($batch_flags == 1)) ;then
			w_logs "3" "正在加载快照";
			status="$R"
		else
			status="$N"
		fi
		end_time=`date "+%Y-%m-%d %H:%M:%S"`
		subtime "$end_time" "$start_time";
		w_logs "3" "1===$monit_file_name";
		if(($sub_time >= $interval_time)) ;then
			ls $tmp_dir/
			mv /$tmp_dir/$monit_file_name $monit_file_dir
			temp_time=`date "+%Y%m%d%H%M%S"`

			#ADD LFY ++ 20120717：若状态未改变，则不记录
			#判断之前的文件是否为空，若空则添加前者状态
#			if [ ! -s $tmp_dir/$monit_file_name ] ;then
#				get_monit_conf;
#				w_logs "3" "文件[$monit_file_name] 是空文件，需要写入前者状态";
#				
#				w_logs "1" "$msg" "$tmp_dir/$monit_file_name"
#			fi
			((add_num++))

			sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
			get_sequence "$add_num";
			monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"
			touch $tmp_dir/$monit_file_name
			start_time=`date "+%Y-%m-%d %H:%M:%S"`
		fi
		w_logs "3" "sub_time[$sub_time]		interval_time[$interval_time]";
		
		#ADD LFY ++ 20120717 不限制时间判断是否失败
#		get_dif_time "$latest_time";
#		if(($dif_time >= 0 && $batch_flags != 0)) ;then
#			status="$F"
#			get_monit_conf;
#			w_logs "1" "$msg" "$tmp_dir/$monit_file_name"
#			continue;
#		fi

		key="$flow_node""$status"
		info_exist "$key";
		exist_flag=$?
		if [ $exist_flag -eq 1 ] ;then
			msg="$table_name&$monitor_time|$process_time|$service_id|$machine_type|$host_ip|$host_name|$flow_node|$status|$desc|$add_num"
			w_logs "1" "$msg" "$tmp_dir/$monit_file_name";
		fi
		if(($jump_flag != 0)) ;then
			w_logs "3" "$host_name 日终结束";

			mv $tmp_dir/$monit_file_name $monit_file_dir
			break;
		fi
		sleep 15s;
	done
}

main "$1";



