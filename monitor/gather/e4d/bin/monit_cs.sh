#cs日终

#!/bin/bash

####全局变量####
Y_date=`date -d "-1 day"  "+%Y%m%d"`
N_date=`date -d "-0 day"  "+%Y%m%d"`

sequence_num=0
sub_time=0
conf_dir="/data2/ADMS/gather/e4d/conf/monit_cs.conf"
#conf_dir="/tmp/test/monit_cs.conf"

declare -a array_row;
declare -a array_msg;
declare -a array_node;
declare -a array_status;
declare -a array_desc;
declare -a array_date;


####

############################基础信息#################################
#节点信息
function array()
{
	local i=0

	#ADD LFY ++  添加starting create .* threads to charge，用于结束脚本
	array_msg=("op=E4D_SIGN"\
			"ServerState check is over!\[charge_date=$Y_date,state=E4D_MODE\]"\
			"ServerState don't run in E4D process. start emergency disposal"\
			"ServerState don't run out of E4D process. start emergency disposal"\
			"batch data loading \[.*\] open error. Stop loading" "loadding batch data error"\
			"batch data is not integral" "loading batch start" "loading batch data is OK"
			"init clean report data is OK" "starting create .* threads to charge")

	array_node=("$recv_e4d" "$E4D_MODE" "$emergency_day_end" "$emergency_day_init" "$load_batch_log" "$load_batch_log"\
			 "$lack_ok" "$load_batch_log" "$load_batch_log" "$DAY_MODE" "$Do_t_logs")

	array_status=("$S" "$S" "$S" "$S" "$F" "$F" "$F" "$R" "$S" "$S" "$S")
	
	array_desc=("recv_e4d" "E4D_MODE" "emergency_day_end" "emergency_day_init" "load_batch_log" "load_batch_log"\
                       "integral_batch" "load_batch_log" "load_batch_log" "DAY_MODE" "Do_t_logs")

	array_date=("$Y_cs_logs" "$Y_cs_logs" "$Y_cs_logs" "$N_cs_logs"\
			"$Y_cs_logs" "$Y_cs_logs" "$Y_cs_logs" "$Y_cs_logs"\
			"$Y_cs_logs" "$N_cs_logs" "$N_cs_logs")
	
	len=${#array_msg[*]}

	local date=`date -d "$Y_date" "+%Y-%m-%d"`
	local now_row=`grep "$date" $Y_cs_logs|wc -l`
	if [ $now_row -ge 2 ] ;then
		now_row=`expr $now_row - 1`
	fi

        for((i=0; i < $len; i++))
        do
		if [ ${array_date[$i]} = $Y_cs_logs ] ;then
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

#读取cs的配置文件
function get_cs_conf()
{
        Y_cs_logs=`cat $cs_conf|grep "logger"|sed 's/logger=//g'|awk -F '_' '{print $1"_"'"$Y_date"'".log"}'`
	N_cs_logs=`cat $cs_conf|grep "logger"|sed 's/logger=//g'|awk -F '_' '{print $1"_"'"$N_date"'".log"}'`
	last_start_time="`date -d "$N_date" "+%Y-%m-%d "`""`cat $cs_conf|grep "last_start_time"|awk -F '=' '{print $2}'`"
	last_end_time=`cat $cs_conf|grep "last_end_time"|awk -F '=' '{print $2}'`
	cluster_id=`cat $cs_conf|grep "cluster_id"|awk -F '=' '{print $2}'`
	batch_base_path=`cat $cs_conf|grep "batch_base_path"|awk -F '=' '{print $2}'`
}


#获取监控脚本的配置文件
function get_monit_conf()
{
        source $conf_dir
}

#检查cs日日志，参数$1:行号 $2:信息，$3：查询的文件名,$4:flow_node,$5:status,$6:desc,$7:end_row
function get_cs_logs()
{
        local temp_row=$1
        local temp_msq=$2
        local temp_filename=$3
	local temp_end_row=$7
        local i=0
	local old_row=$1

	if [ ! -f $3 ] ;then
		w_logs "3" "filename[$3] not exist";
		row=1
		return 1
	fi
	
#	local row_array=(`sed -n ''"$temp_row"',$p' $temp_filename |perl -ne '$i++;if(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[/){$time=$1;}\
#				if(/'"$temp_msq"'/){$flag=1;print $time," ",$i,"\n";}if(eof and $flag ne 1){print 0," ",$i,"\n"}'`)
	
	local row_array=(`sed -n ''"$temp_row"','"$temp_end_row"'p' $temp_filename |perl -ne '$i++;if(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[/){$time=$1;}\
				if(/'"$temp_msq"'/){$flag=1;print $time," ",$i,"\n";}if(eof and $flag ne 1){print 0," ",$i,"\n"}'`)
	local row_length=${#row_array[*]}

	if [ "-${row_array[0]}" = "-" ] ;then
		row=$1
		w_logs "3" "文件数量没有变化,信息[$2],文件[$3]重新定位[$old_row -> $row]";
		return 2
	fi	

        if [ "${row_array[0]}" = "0" ] ;then
                row=`expr ${row_array[1]} + $1 - 1`
		w_logs "3" "未查到信息[$2],文件[$3]重新定位[$old_row -> $row]";
                return 1
        fi
	key="$4""$5"
	

	#ADD LFY ++ 2012.7.17:排除多余信息（E4D_MODE），只记录一条
	if [ "-$2" = "-ServerState check is over!\[charge_date="$Y_date",state=E4D_MODE\]" -o "-$2" = "-starting create .* threads to charge" ]; then
		info_exist "$key";
		if [ $? -eq 1 ] ;then
			process_time="${row_array[0]}"" ${row_array[1]}"
			get_date;
			((row_flag++))
			msg="$table_name&$monitor_time|$process_time|$service_id|$machine_type|$host_ip|$host_name|$4|$5|$6|$row_flag"
			w_logs "1" "$msg" "$tmp_dir/$monit_file_name"
		fi
	else
		for ((i=0; i < $row_length; ))
        	do
                	process_time="${row_array[$i]}"" ${row_array[$((i+1))]}"
			((row_flag++))
		        get_date;
        		i=$((i+3))
                	msg="$table_name&$monitor_time|$process_time|$service_id|$machine_type|$host_ip|$host_name|$4|$5|$6|$row_flag"
		        w_logs "1" "$msg" "$tmp_dir/$monit_file_name"
		done
	fi
	#row=$((${row_array[$(($row_length-1))]}+$1))
	row=$temp_end_row
	
	w_logs "3" "查到信息[$2],文件[$3]重新定位[$old_row -> $row]";
        return 0
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
	local i=0
        for((i=0; i<$eth_num; i++))
        do  
                onboot=`grep "ONBOOT" /etc/sysconfig/network-scripts/ifcfg-eth$i|awk '{if($0 ~ /ONBOOT=yes/) {print "yes"} else {print "no"}}'`
                if [ "$onboot" == "yes" ] ;then
                        host_ip=`grep "IPADDR" /etc/sysconfig/network-scripts/ifcfg-eth$i|awk -F '=' '{print $2}'`
                        break;
                fi  
        done
}


#获取自增num：$1：输入的数据1,2,3
function get_sequence()
{
        temp_num1=$((`echo $1|awk '{print length($0)}'` + 1))
        temp_num2=`echo $sequence_init|awk '{print substr($0,'"$temp_num1"')}'`
        sequence_num="$temp_num2""$1"
}

#写日志信息,$1:输入类型（1追加或2修改），$2:输入信息,$3路径+文件名
function w_logs()
{
        if(($1 == 1)) ;then
                echo "$2">>$3
        elif(($1 == 2)) ;then
                echo "$2">$3
	else
		echo "[`date "+%Y-%m-%d %H:%M:%S"`] [INFO] $2" >> $logs_dir/mt_cs_$N_date.log
        fi
}


#获取时间之差
function get_dif_time()
{
	ctime=`date -d "$N_date"  "+%Y-%m-%d %H:%M:%S"`
	temp_t1=`date -d "$1" +%s`
	temp_t2=`date -d "$ctime" +%s`
	dif_time=$(($temp_t2 - $temp_t1))
}

function subtime()
{
        time1=`date -d "$1" +%s`
        time2=`date -d "$2" +%s`
        sub_time=$(($time1-$time2))
}

#数据是否已经存在 $1:比较的key1 返回值：0：存在 1：不存在
function info_exist()
{
        local key1=$1
        if [ "_$key1" != "_$temp_key" ] ;then
                w_logs "3" "本次插入的数据在文件中不存在，上次插入的key是[$temp_key],这次插入的key是[$key1]";
                temp_key=$key1
                return 1
        fi
        w_logs "3" "数据[$key1]已经在文件中存在";
        return 0
}
####

###############################功能实现########################
#检查batch是否正确
function check_batch_num()
{
	#2012-06-13-05_09_21
#获取batch路径
	batch_current_dir="$batch_base_path/current"
	w_logs "3" "batch_history_dir=[$batch_history_dir];batch_current_dir=[$batch_current_dir]"
	
	batch_array=($batch_logs)
	batch_length=${#batch_array[*]}
	batch_num=0

	batch_num1=0
	local i=0
	for((i=0; i<$batch_length; i++))
	do
		#当current目录下无，则到history下寻找
		if [ ! -f $batch_current_dir/${batch_array[$i]} ] ;then

			w_logs "3" "所查的数据日期为：$N_date";
			ctime=`date -d "$N_date"  "+%Y-%m-%d"`
			batch_history_dir=`find $batch_base_path/history -name "$ctime*" |sort -r|sed -n 1p`
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

	#判断batch_logs加载是否结束 0:加载成功 length:正在加载 length+1:错误信息
	if(($batch_num1 == $batch_length)) ;then
		batch_num=0
	elif(($(($batch_num1+$batch_num)) == $batch_length)) ;then
		batch_num=$batch_length
	else
		batch_num=$(($batch_length+1))
	fi

	return $batch_num
}

#batch文件是否收到，且数量是否正确
function mount_batch()
{
	w_logs "3" "开始检查batch"
	check_batch_num;
	local batch_num_ok=$?

	if(($batch_num_ok == $batch_length )) ;then
		return 1
	
	elif(($batch_num_ok == $(($batch_length+1)))) ;then
                return 2
        elif(($batch_num_ok==0)) ;then
                return 0
        fi
		
	w_logs "3" "未知状态";
	return 3
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

####


##########################################最终实现
function main()
{
	row_flag=0
#检查时间与获取cs中的配置文件
	check_time "$1";
	set_add_num;
	get_monit_conf;
	w_logs "3" "cs 日终开始	first: `date "+%Y-%m-%d %H:%M:%S"`";
	get_cs_conf;
	#获取服务器信息（ip+name）
        get_server_info;
	local i=0
	local exit_flag1=0
	local exit_flag2=0
	local new_file=0
	local end_row=0
	array;
	local while_num=0

	w_logs "3" "y_date[$Y_date] n_date[$N_date]";

#暂时记录
	if [ ! -d $monit_file_dir ] ;then
		mkdir $monit_file_dir
        fi

        add_num=$Add_num
	sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
	get_sequence "$add_num";
	process_time=`date -d "-0 day"  "+%Y-%m-%d %H:%M:%S"`
	
        start_time=`date "+%Y-%m-%d %H:%M:%S"`
        end_time=`date "+%Y-%m-%d %H:%M:%S"`
        temp_time=`date "+%Y%m%d%H%M%S"`
        monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"
	
	touch $tmp_dir/$monit_file_name
#开始执行
	#获取信号，开始日终
	while [ 1 ]
	do
		w_logs "3" "=============================开始第[$while_num]次循环==================="
		get_date;
		get_monit_conf;
                end_time=`date "+%Y-%m-%d %H:%M:%S"`
                subtime "$end_time" "$start_time";

                if(($sub_time>=$interval_time)) ;then
                        temp_time=`date "+%Y%m%d%H%M%S"`
			mv $tmp_dir/$monit_file_name $monit_file_dir
                       	((add_num++))
#			touch $tmp_dir/$monit_file_name
			sed -i 's/Add_num.*/Add_num='""$(($add_num+1))""'/g' $conf_dir
                        get_sequence "$add_num";
                        monit_file_name="mt_$cluster_name"_"$host_name"_"e4d_$temp_time.$sequence_num"
			touch $tmp_dir/$monit_file_name
                        start_time=`date "+%Y-%m-%d %H:%M:%S"`
		fi

		#获取cs日志中信息,按规则获取	
                for((i=0; i < $len; i++))
                do
			if [ "-${array_date[$i]}" != "-$Y_cs_logs" ] ;then
				if [ $new_file -le 2 ] ;then
					w_logs "3" "ignore file[${array_date[$i]}], new_file_flag is [$new_file]";
					continue;
				fi
				w_logs "3" "do file[${array_date[$i]}], new_file_flag is [$new_file]";
			fi
			
			if [ $i -eq 0 ] ;then
				end_row=`cat ${array_date[$i]} |wc -l`
				sleep 1s;
				w_logs "3" "end_row[$end_row]"
				
			fi
			get_cs_logs "${array_row[$i]}" "${array_msg[$i]}" "${array_date[$i]}" "${array_node[$i]}" "${array_status[$i]}" "${array_desc[$i]}" "$end_row";
			info_flag=$?
			
			if [ $i -eq 0 ] ;then
				array_row[$i]=$row
			else
				array_row[$i]=${array_row[0]}
			fi
			
			if [ "-${array_msg[$i]}" = "-starting create .* threads to charge" -a $info_flag -eq 0 ] ;then
				w_logs "3" "[${array_msg[$i]}]success";
				((exit_flag1++))
			fi
			
			if [ "-${array_msg[$i]}" = "-loading batch data is OK" -a $info_flag -eq 0 ] ;then
				w_logs "3" "[${array_msg[$i]}]success";
				((exit_flag2++))
			fi
		done
		
		if [ -f $N_cs_logs ] ;then
			((new_file++))
		else
			new_file=0
		fi

		if [ $new_file -eq 2 ] ;then
			w_logs "3" "open new logs file[$Y_cs_logs --> $N_cs_logs]"
			local j=0	
			for((j=0; j < $len; j++));
			do
				if [ "-${array_date[$j]}" != "-$N_cs_logs" ] ;then
					array_date[$j]=$N_cs_logs
					array_row[$j]=1
				fi
			done
		fi

		if(($exit_flag1 != 0 && $exit_flag2 != 0)) ;then
			mv $tmp_dir/$monit_file_name $monit_file_dir
			break;
		fi
		((while_num++))
		sleep 15s
	done
	w_logs "3" "cs日终结束	end: `date "+%Y-%m-%d %H:%M:%S"`";
}

main "$1";

#echo "$last_start_time		$ctime		$dif_time"

