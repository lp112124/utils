#!/bin/bash

CLUSTER=2
CURR_DIR="/data1/es_logs/current"
HIS_DIR="$/data1/es_logs/history"

minute=`date +%-M`
if [ $minute -lt 20 ]
then
    echo "not now" 
    exit 0
fi

hour=`date -d last-hour +%H`
scriptPath=`dirname $0`
if [ -f $scriptPath/$hour.ok ]
then
    echo "file been transfered"
    exit 0
fi
rm -f $scriptPath/*.ok
#exit 0
yest=`date -d last-day +%Y%m%d`
today=`date +%Y%m%d`
#ES_DIR=/data1/es_logs/
DES_DIR=$1

if [ $hour -ne 23 ]; then
        ls ${CURR_DIR} |grep "es*_${today}_${hour}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp ${CURR_DIR}/es*_${today}_${hour}* $DES_DIR
                if [ $hour -eq 0 ]; then
                        cp ${HIS_DIR}/${today}/es_0*_${yest}_* $DES_DIR
                fi
        fi
        ls ${HIS_DIR}/${today} |grep "es_0${CLUSTER}.*_${today}_${hour}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp ${HIS_DIR}/${today}/es_0${CLUSTER}*_${today}_${hour}* $DES_DIR
                if [ $hour -eq 0 ]; then
                        cp ${HIS_DIR}/${today}/es_0*_${yest}_* $DES_DIR
                fi
        fi
        cd $DES_DIR
        tar zcf cs${CLUSTER}_${today}_${hour}_es.tar.gz es_0${CLUSTER}*.log
        
        if [ $? -ne 0 ];then
                exit 1
        fi
        
        echo "pack cs${CLUSTER}${today}_${hour}_es.tar.gz success."
        rm ${DES_DIR}/es_0${CLUSTER}*

       
else
        ls ${CURR_DIR} |grep "es_0${CLUSTER}.*_${yest}_${hour}*" > /dev/null
        if [ $? -eq 0 ]; then
                  cp ${CURR_DIR}/es_0${CLUSTER}*_${yest}_${hour}* $DES_DIR
        fi
        ls ${HIS_DIR}/${yest} |grep "es_0${CLUSTER}.*_${yest}_${hour}*" > /dev/null
        if [ $? -eq 0 ]; then
                cp ${HIS_DIR}/${yest}/es_0${CLUSTER}*_${yest}_${hour}* $DES_DIR
        fi
        cd $DES_DIR
        tar zcf cs${CLUSTER}_${yest}_${hour}_es.tar.gz es_0${CLUSTER}*_${yest}_${hour}*.log
        if [ $? -ne 0 ];then
               exit 1
        fi


        rm ${DES_DIR}/es_0${CLUSTER}*
        
fi
touch $scriptPath/$hour.ok

