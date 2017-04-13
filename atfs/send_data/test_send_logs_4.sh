##! /bin/bash -
yest=`date -d last-day +%Y%m%d`
today=`date +%Y%m%d`
h=11
T_LOGS_DIR="/data1/es_logs/04"
if [ $h -ne 23 ]; then
	if [ -e $T_LOGS_DIR/${today}/cs4_${today}_${h}_es.tar.gz.ok ]; then
		ssh -p 57764 rerun "mkdir -p $T_LOGS_DIR/${today}"
		scp -P 57764 $T_LOGS_DIR/${today}/cs4_${today}_${h}_es.tar.gz rerun:$T_LOGS_DIR/${today}
		rm $T_LOGS_DIR/${today}/cs4_${today}_${h}_es.tar.gz.ok
	else
		exit 1
	fi
else
	if [ -e $T_LOGS_DIR/${yest}/cs4_${yest}_${h}_es.tar.gz.ok ]; then
		ssh -p 57764 rerun "mkdir -p $T_LOGS_DIR/${yest}"
                scp -P 57764 $T_LOGS_DIR/${yest}/cs4_${yest}_${h}_es.tar.gz rerun:$T_LOGS_DIR/${yest}
		scp -P 57764 $T_LOGS_DIR/${yest}/cs4_${yest}_${h}_es.tar.gz.ok rerun:$T_LOGS_DIR/${yest}/es.ok
		rm $T_LOGS_DIR/${yest}/cs4_${yest}_${h}_es.tar.gz.ok
	else
		exit 1
	fi
fi
rm /tmp/test_send_logs_4.sh
