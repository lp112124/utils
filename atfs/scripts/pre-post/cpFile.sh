#!/bin/bash

CLUSTER=2
today=`date +%Y%m%d`
PAR_DIR=`dirname $0`
SRC_DIR="/data/home/xyq/test/ADMS/atfs/scripts/es_logs"
LOCK_FILE="${PAR_DIR}/t.lock"
DEST_DIR=$1
PROCESS_LIST="${PAR_DIR}/t_list"


function getRecord(){
    local record=`grep -n $1 $PROCESS_LIST`
    if [ "$record" ];then
        echo $record
    fi
}


function sortFileList(){
    local list=$1
    local tmpfile="${PAR_DIR}/tmp_list.txt"
    
    > $tmpfile
    local item
    for item in $list;do
        #if [ -f $item ];then
            echo $item >> $tmpfile
        #fi
    done

    list=`sort $tmpfile`
   
    for item in $list;do
        echo -e $item
    done
    
}

function getFileList(){
    if [ -d $1 ];then
        #local list=`find $1 -maxdepth 1 -type f`
        local list=`ls $1`
        if [ "$list" ];then
            for item in $list;do
                echo -e "$item"
            done
        fi
    fi   
}

# get the list of file which need to scp
function getScpList(){
    local srcDir=$1
    local list=`getFileList $srcDir`
    #list=`sortFileList "$list"`

    local item

    for item in $list;do

        local record=`getRecord $item`
        # if the file not been transfered
        if [ ! "$record" ];then
            echo -e $item
        fi
    done
}

# copy the file list to dest-dir to scp
function cpScpFile(){
    local srcDir=$1
    local desDir=$2
    local day=`cat $LOCK_FILE`
    local today=`date +%Y%m%d`
    local list=`getScpList ${srcDir}/${day}`
    local item

    if [ "$list" ];then
        for item in $list;do            
            cp -a ${srcDir}/${day}/${item} ${desDir}/${item}-${day}
            if [ $? -eq 0 ];then
                echo -e $item >> $PROCESS_LIST
            else
                exit 1
            fi
        done
    else
        # if same day, then return
        if [ "$day" == "$today" ];then
            return
        fi
        
        # if new dir found
        if [ -d "${srcDir}/${today}" ];then
            echo -e $today > $LOCK_FILE
            > $PROCESS_LIST
        fi
    fi
}


day=$today
if [ ! -f $LOCK_FILE ]
then
    echo $today > $LOCK_FILE
fi

if [ ! -f $PROCESS_LIST ]
then 
    > $PROCESS_LIST
fi


cpScpFile $SRC_DIR $DEST_DIR
