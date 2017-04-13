#!/bin/bash
CLUSTER=2
DLOG_DIR="/data1/dc/dc$CLUSTER/data/dc_logs/current/"
yest=`date -d last-day +%Y%m%d`
today=`date +%Y%m%d`
DLOG_TMP="/data3/ATS/ats/data/dlog${CLUSTER}/"
LOCK_FILE="/data3/ATS/ats/srcScripts/dlog$CLUSTER/dc$CLUSTER.lock"
DEST_DIR=$1

if [  -f $LOCK_FILE ]
then
    content=`cat $LOCK_FILE`
    day=`echo $content | awk -F '_' '{print $1}'`
    hour=`echo $content | awk -F '_' '{print $2}'`
    next_hour=`printf "%02d" $((10#$hour+1))`
    echo $day, $hour, $next_hour
    if [ $next_hour -ne 24 ]
    then
        next_dlog=`ls $DLOG_DIR/$day/*_${day}_${next_hour}*.log`
    else
        next_dlog=`ls $DLOG_DIR/$day/${CLUSTER}_dc.ok`
    fi
    
    if [ $? -ne 0 ]
    then
        echo "not ready to pack dlog"
        exit 1
    else
        if [ $next_hour -eq 24 ]
        then
            cp $DLOG_DIR/$day/dc_0${CLUSTER}*_${day}_$hour*.log $DLOG_TMP
            cp $DLOG_DIR/$day/${CLUSTER}_dc.ok $DLOG_TMP
            cd $DLOG_TMP
            tar -czvf dc${CLUSTER}_${day}_${hour}.tar.gz dc_0${CLUSTER}*_${day}_${hour}*.log ${CLUSTER}_dc.ok
            if [ $? -eq 0 ]
            then
                mv dc${CLUSTER}_${day}_${hour}.tar.gz $DEST_DIR
                #echo ${day}_${next_hour} > $LOCK_FILE
            fi
            rm -f $DLOG_TMP/*.log $DLOG_TMP/${CLUSTER}_dc.ok
            rm -f $LOCK_FILE
        else
            cp $DLOG_DIR/$day/dc_0${CLUSTER}*_${day}_${hour}*.log ${DLOG_TMP}
            cd $DLOG_TMP
            tar -czvf dc${CLUSTER}_${day}_${hour}.tar.gz *.log
            if [ $? -eq 0 ]
            then
                mv dc${CLUSTER}_${day}_${hour}.tar.gz $DEST_DIR 
                echo ${day}_${next_hour} > $LOCK_FILE
            fi
            rm -f $DLOG_TMP/*.log    
        fi
    fi
        
else
    hour='00'
    next_dlog=`ls $DLOG_DIR/$today/*_01????.log`
    pack_flag=$?
    if [ $pack_flag -eq 0 ] # ok to pack hour=00 and day before
    then
        cp $DLOG_DIR/$today/dc_0$CLUSTER*_${yest}_*.log $DLOG_TMP
        cp $DLOG_DIR/$today/dc_0$CLUSTER*_${today}_$hour*.log $DLOG_TMP
        cd $DLOG_TMP
        tar -czvf dc${CLUSTER}_${today}_$hour.tar.gz *.log
	mv dc${CLUSTER}_${today}_$hour.tar.gz $DEST_DIR
        rm -f $DLOG_TMP/*.log
        echo "${today}_01" > $LOCK_FILE
    fi
fi
        
    
    
