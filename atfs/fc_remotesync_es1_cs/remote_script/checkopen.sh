#!/bin/bash

function checkOpenFile(){
	/usr/sbin/lsof $1
	if [ $? -eq 0 ];then
		return 1
	else 
		return 0
	fi
}

checkOpenFile "$1"

exit $?
