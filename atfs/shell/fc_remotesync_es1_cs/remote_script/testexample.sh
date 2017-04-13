#!/bin/bash

#find $1 -iname "*.txt" -ctime -3
ok_stat=`find $1 -iname "*.ok"`
if [ -z "$ok_stat" ]; then
	exit 0
else
	find $1 -iname "*.txt"
	exit 0
fi
