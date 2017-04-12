#cc日终
#!/bin/bash

####全局变量####
Y_date=`date -d "-1 day"  "+%Y%m%d"`
N_date=`date -d "-0 day"  "+%Y%m%d"`
Y_cc_logs=""
N_cc_logs=""
sequence_num=0
sub_time=0
conf_dir="/data2/ADMS/gather/e4d/conf/monit_cc.conf"
#conf_dir="/tmp/test/monit_cc.conf"

declare -a array_row;
declare -a array_msg;
declare -a array_node;
declare -a array_status;
declare -a array_desc;
declare -a array_date;

temp_key=""
####

############################基础信息#################################
#节点信息
function array()
{
	echo "Y_cc_logs[$Y_cc_logs] N_cc_logs[$N_cc_logs]"
	local i=0

	array_msg=("ServerState ready to run in E4D process" "send E4D_SIGN is error"\
                        "All cluster stop charge is ok! start E4D process" "ServerState don't run in E4D process. start emergency disposal"\
                        "DE4. backup BDB" "bdb backup is ok" "DE5. move report data"\
                        "Day End is over! start Day Init" "DI4. call day init store procedure"\
                        "DI5. dump batch data" "DI6. switch server stat to DAY_MODE"\
			"bdb backup error" "dump batch .* query error"\
			"signal to switch status to E4D_MODE" "signal to switch status to DAY_MODE"\
			"D4EProc is over")

        array_node=("$send_e4d" "$send_e4d" "$recv_pause_flag" "$emergency_day_end"\
                        "$backup_bkdb" "$backup_bkdb" "$report_migrate" "$report_migrate"\
                        "$call_procedure" "$dump_batch_log" "$DAY_MODE"	"$backup_bkdb"\
			"$dump_batch_log" "$signal_e4d" "$signal_day" "$END_D4E")
        
        array_status=("$S" "$F" "$S" "$S"\
			"$R" "$S" "$R" "$S"\
			"$S" "$S" "$S" "$F"\
			"$F" "$S" "$S" "$S")
        
        array_desc=("send_e4d" "send_e4d" "recv_pause_flag" "emergency_day_end"\
                        "backup_bkdb" "backup_bkdb" "report_migrate" "report_migrate"\
                        "call_procedure" "dump_batch_log" "DAY_MODE" "backup_bkdb_error"\
			"dump_batch_log_error" "signal_e4d" "signal_day" "END_D4E")

        array_date=("$Y_cc_logs" "$Y_cc_logs" "$Y_cc_logs" "$Y_cc_logs"\
                        "$N_cc_logs" "$N_cc_logs" "$N_cc_logs" "$N_cc_logs"\
                        "$N_cc_logs" "$N_cc_logs" "$N_cc_logs" "$N_cc_logs"\
			"$N_cc_logs" "$N_cc_logs" "$N_cc_logs" "$N_cc_logs")

	len=${#array_msg[*]}

	local date=`date -d "$Y_date" "+%Y-%m-%d"`
	local now_row=`grep "$date" $Y_cc_logs|wc -l`
	if [ $now_row -ge 2 ] ;then
                now_row=`expr $now_row - 1`
        fi	
	
	for((i=0; i < $len; i++))
	do
		if [ ${array_date[$i]} = $Y_cc_logs ] ;then
			array_row[$i]=$now_row;
		else
			array_row[$i]=1;
                fi
	done

}

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

#获取监控脚本的配置文件
function get_monit_conf()
{
	source $conf_dir
}

#获取cc的配置文件信息
function get_cc_conf()
{
	Y_cc_logs=`cat $cc_conf|grep "logger"|sed 's/logger=//g'|awk -F '_' '{print $1"_"'"$Y_date"'".log"}'`
	N_cc_logs=`cat $cc_conf|grep "logger"|sed 's/logger=//g'|awk -F '_' '{print $1"_"'"$N_date"'".log"}'`
	last_start_time="`date -d "$N_date" "+%Y-%m-%d "`""`cat $cc_conf|grep "last_start_time"|awk -F '=' '{print $2}'`"
	db_backup_path=`cat $cc_conf|grep "db_backup_path"|awk -F '=' '{print $2}'`
	clog_base_path=`cat $cc_conf|grep "clog_base_path"|awk -F '=' '{print $2}'`
	batch_base_path=`cat $cc_conf|grep "batch_base_path"|awk -F '=' '{print $2}'`
}

#得到日期时间
function get_date()
{
	sleep 1s;
	monitor_time=`date "+%Y-%m-%d %H:%M:%S"`
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

#写日志信息,$1:输入类型（1追加或2修改），$2:输入信息,$3路径+文件名
function w_logs()
{
	if(($1 == 1)) ;then
		echo "$2">>$3
	elif(($1 == 2)) ;then
		echo "$2">$3
	else
		echo "[`date "+%Y-%m-%d %H:%M:%S"`] [INFO] $2" >> $logs_dir/mt_cc_$N_date.log
	fi
}

#获取时间之差
function get_dif_time()
{
	ctime=`date "+%Y-%m-%d %H:%M:%S"`
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
	time1=`date -d "$1" +%s`
        time2=`date -d "$2" +%s`
	sub_time=$(($time1-$time2))
}

#得到key列
function get_key_list()
{
	key_list=(`grep "msg" /data1/monit_day_end/monit_cc.conf|sed 's/[=,",&,|,$]/ /g;' |awk '{for(i=1;i<=NF;i++){if($i=="flow_node")\
		n1=i;else if($i=="status") n2=i}print n1" "n2}'`)
}

#数据是否已经存在 $1:比较的key1	返回值：0：存在	1：不存在
function info_exist()
{
	key1=$1
	
	if [ "_$key1" != "_$temp_key" ] ;then
		w_logs "3" "key[$temp_key -> $key1]";
		temp_key=$key1
		return 1
	fi
	w_logs "3" "key[$key1]";
	return 0
}

##

###############################功能实现########################
#获取cc日志信息行号 参数$1:行号 $2:信息，$3：查询的文件名,$4:flow_node,$5:status,$6:desc
function get_cc_logs()
{
       	local temp_row=$1
        local temp_msq=$2
        local temp_filename=$3
        local i=0

	if [ ! -f $3 ] ;then
		w_logs "3" "filename[$3] not exist";
		row=1
		return 1
	fi

	local row_flag=0
	local row_array=(`sed -n ''"$temp_row"',$p' $temp_filename |perl -ne '$i++;if(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[/){$time=$1;}\
                                if(/'"$temp_msq"'/){$flag=1;print $time," ",$i,"\n";}if(eof and $flag ne 1){print 0," ",$i,"\n"}'`)
        local row_length=${#row_array[*]}

	if [ "-${row_array[0]}" = "-" ] ;then
		row=$1
		w_logs "3" "文件数量没有变化,信息[$2],文件[$3]重新定位[$temp_row -> $row]";
		return 1
	fi
	
	if [ "${row_array[0]}" = "0" ] ;then	
		row=`expr ${row_array[1]} + $1 - 1`
		w_logs "3" "未查到信息[$2],文件[$3]重新定位[$temp_row -> $row]";
		return 1
	fi

        for ((i=0; i < $row_length; ))
        do
		process_time="${row_array[$i]}"" ${row_array[$((i+1))]}"
		row_flag=`expr $1 + ${row_array[$((i+2))]} - 1`
		get_date;
		i=$((i+3))
		msg="$table_name&$monitor_time|$process_time|$service_id|$machine_type|$host_ip|$host_name|$4|$5|$6|$row_flag"
		w_logs "1" "$msg" "$tmp_dir/$monit_file_name";
		w_logs "3" "[$msg]to[$tmp_dir/$monit_file_name]";
        done

	row=$((${row_array[$(($row_length-1))]}+$1))
	w_logs "3" "查到信息[$2],文件[$3]重新定位[$temp_row -> $row]";
        return 0
}

#检查快照生成是否成功
function check_batch()
{
	batch_array=($batch_logs)
	batch_length=${#batch_array[*]}
	local i=0

	for((i=0; i<$batch_length; i++))
	do
		for((j=2; j<=4; j++))
		do
			if [ ! -f $batch_base_path/current/0$j/${batch_array[$i]} ] ;then
				if [ ! -f $batch_base_path/history/0$j/$N_date/${batch_array[$i]} ] ;then
					w_logs "3" "dump生成失败！[$batch_base_path/history/0$j/$N_date/${batch_array[$i]}]";
					return 1
				else
					w_logs "3" "dump生成成功！[$batch_base_path/history/0$j/$N_date/${batch_array[$i]}]";
				fi
			else
				w_logs "3" "dump生成成功！[$batch_base_path/current/0$j/${batch_array[$i]}]";
			fi
		done
	done
	w_logs "3" "dump成功";
	return 0
}


#设置自增编号
function set_add_num()
{
	get_monit_conf;	
	if [ "-$now_date" = "-" ] ;then
		echo "now_date=$N_date" >>$conf_dir
		sed -i 's/Add_num.*/Add_num=1/g' $conf_dir
	elif [ $N_date -ne $now_date ] ;then
		sed -i 's/Add_num.*/Add_num=1/g' $conf_dir
		sed -i 's/now_date.*/now_date='"$N_date"'/g' $conf_dir
	fi
}


##########################################最终实现
function main()
{

	#获取服务器信息（ip+name）
	get_server_info;
	#set_add_num;	get_monit_conf;	位置不能改变***	
	while_num=0
        check_time "$1";
	set_add_num;
	get_monit_conf;
	w_logs "3" "first: `date "+%Y-%m-%d %H:%M:%S"`";

	get_cc_conf;
	
	local info_flag=0

#暂时添加
        if [ ! -d $monit_file_dir ] ;then
                mkdir $monit_file_dir
        fi

        add_num=$Add_num
	sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
	get_sequence "$add_num";
        start_time=`date "+%Y-%m-%d %H:%M:%S"`
        end_time=`date "+%Y-%m-%d %H:%M:%S"`
	temp_time=`date "+%Y%m%d%H%M%S"`
	monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"

	touch $tmp_dir/$monit_file_name
	local exit_flag=0	
	array;

        while [ 1 ]
        do
		w_logs "3" "=============================开始第[$while_num]次循环==================="
		get_date;
		get_monit_conf;
               	end_time=`date "+%Y-%m-%d %H:%M:%S"`
               	subtime "$end_time" "$start_time";

               	if(($sub_time>=$interval_time)) ;then
			temp_time=`date "+%Y%m%d%H%M%S"`

			 #判断之前的文件是否为空，若空则添加前者状态
	               #if [ ! -s $tmp_dir/$monit_file_name ] ;then
                       #         w_logs "3" "这个文件为空文件";
                       #         w_logs "1" "$msg" "$tmp_dir/$monit_file_name"
                       # fi
			
			mv $tmp_dir/$monit_file_name  $monit_file_dir/
			((add_num++))
#			touch $tmp_dir/$monit_file_name
			sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
                        get_sequence "$add_num";
                        monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"
			touch $tmp_dir/$monit_file_name
                        start_time=`date "+%Y-%m-%d %H:%M:%S"`
                fi

                get_cc_conf;
		
		#获取cc日志中信息,按规则获取
		for((i=0; i < $len; i++))
		do
			get_cc_logs "${array_row[$i]}" "${array_msg[$i]}" "${array_date[$i]}" "${array_node[$i]}" "${array_status[$i]}" "${array_desc[$i]}";
			info_flag=$?
			
			#检查压缩文件是否正确
			if [ "-${array_msg[$i]}" = "-bdb backup is ok" -a $info_flag -eq 0 ] ;then
				if [ ! -f $db_backup_path/cc_backup_$Y_date.tar ] ;then
					get_date;
					msg="$table_name&$monitor_time|$monitor_time|$service_id|$machine_type|$host_ip|$host_name|${array_node[$i]}|$F|${array_desc[$i]}_data|`expr $row - 1`"
			                w_logs "1" "$msg" "$tmp_dir/$monit_file_name";
					w_logs "3" "[$msg]to[$tmp_dir/$monit_file_name]";
				fi
			elif [ "-${array_msg[$i]}" = "-DI6. switch server stat to DAY_MODE" -a $info_flag -eq 0 ] ;then
				check_batch;
				batch_flag=$?
				if [ $batch_flag -eq 1 ] ;then
					get_date;
                                        msg="$table_name&$monitor_time|$monitor_time|$service_id|$machine_type|$host_ip|$host_name|$dump_batch_log|$F|batch_error|`expr $row - 1`"
                                        w_logs "1" "$msg" "$tmp_dir/$monit_file_name";
					w_logs "3" "[$msg]to[$tmp_dir/$monit_file_name]";
				fi
			elif [ "-${array_msg[$i]}" = "-D4EProc is over" -a $info_flag -eq 0 ] ;then
				((exit_flag++))
			fi
				
			array_row[$i]=$row
		done
		if(($exit_flag != 0)) ;then
			mv $tmp_dir/$monit_file_name  $monit_file_dir/
			w_logs "3" "cc 日终结束";
			break;
		fi
		((while_num++))
		sleep 30s;
	done
	w_logs "3" "end: `date "+%Y-%m-%d %H:%M:%S"`";
}

main "$1";

