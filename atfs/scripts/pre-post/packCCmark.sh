#!/bin/bash
CLUSTER=2
CM_DIR="/data1/dc/dc$CLUSTER/data/cc_mark"
yest=`date -d last-day +%Y%m%d`
today=`date +%Y%m%d`
CM_TMP="/data3/ATS/ats/data/cc_mark/"
LOCK_FILE="/data3/ATS/ats/srcScripts/cc_mark/cc_mark.lock"
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
        next_dlog=`ls $CM_DIR/$day/*_${day}_${next_hour}*.log`
    else
        next_dlog=`ls $CM_DIR/$day/cc.ok`
    fi
    
    if [ $? -ne 0 ]
    then
        echo "not ready to pack dlog"
        exit 1
    else
        if [ $next_hour -eq 24 ]
        then
            cp $CM_DIR/$day/es*_${day}_$hour*.log $CM_TMP
            cp $CM_DIR/$day/cc.ok $CM_TMP
            cd $CM_TMP
            tar -czvf es_${day}_${hour}.tar.gz es*${day}_$hour*.log cc.ok
            mv es_${day}_${hour}.tar.gz $DEST_DIR
            rm -f $CM_TMP/*.log $CM_TMP/cc.ok
            rm -f $LOCK_FILE
        else
            cp $CM_DIR/$day/es*${day}_$hour*.log ${CM_TMP}
            cd $CM_TMP
            tar -czvf es_${day}_${hour}.tar.gz *.log
            if [ $? -eq 0 ]
            then
                mv es_${day}_${hour}.tar.gz $DEST_DIR 
                echo ${day}_${next_hour} > $LOCK_FILE
            fi
            rm -f $CM_TMP/*.log    
        fi
    fi
        
else
    hour='00'
    ext_dlog=`ls $CM_DIR/$today/*_01????.log`
    pack_flag=$?
    if [ $pack_flag -eq 0 ] # ok to pack hour=00 and day before
    then
        cp $CM_DIR/$today/es*${yest}*.log $CM_TMP
        cp $CM_DIR/$today/es*${today}_$hour*.log $CM_TMP
        cd $CM_TMP
        tar -czvf es_${today}_$hour.tar.gz *.log
	mv es_${today}_$hour.tar.gz $DEST_DIR
        rm -f $CM_TMP/*.log
        echo "${today}_01" > $LOCK_FILE
    fi
fi
        
    
    
