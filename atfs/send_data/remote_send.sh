#! /bin/bash -
yest=`date -d last-day +%Y%m%d`
today=`date +%Y%m%d`
h=`date -d last-hour +%H`
ES_DIR="/data1/es_logs/history/tmp"
if [ $h -ne 23 ]; then
        ls /data1/es_logs/current |grep "es_04.*_${today}_${h}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp /data1/es_logs/current/es_04*_${today}_${h}* $ES_DIR
        fi
        ls /data1/es_logs/history/${today} |grep "es_04.*_${today}_${h}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp /data1/es_logs/history/${today}/es_04*_${today}_${h}* $ES_DIR
        fi
        cd $ES_DIR
	rename .log~ .log *~
        tar zcf cs4_${today}_${h}_es.tar.gz es_04*_${today}_${h}*.log
        scp -P 57764 ${ES_DIR}/cs4_${today}_${h}_es.tar.gz msmq:/tmp
        ssh -p 57764 msmq "touch /tmp/cs4_${today}_${h}_es.tar.gz.ok"
        rm ${ES_DIR}/*
        rm /tmp/remote_send.sh
else
        ls /data1/es_logs/current |grep "es_04.*_${yest}_${h}*" > /dev/null
        if [ $? -eq 0 ]; then
                  cp /data1/es_logs/current/es_04*_${yest}_${h}* $ES_DIR
        fi
        ls /data1/es_logs/history/${yest} |grep "es_04.*_${yest}_${h}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp /data1/es_logs/history/${yest}/es_04*_${yest}_${h}* $ES_DIR
        fi
        cd $ES_DIR
	rename .log~ .log *~
        tar zcf cs4_${yest}_${h}_es.tar.gz es_04*_${yest}_${h}*.log
        scp -P 57764 ${ES_DIR}/cs4_${yest}_${h}_es.tar.gz msmq:/tmp
        ssh -p 57764 msmq "touch /tmp/cs4_${yest}_${h}_es.tar.gz.ok"
        rm ${ES_DIR}/*
        rm /tmp/remote_send.sh
fi
