#!/usr/bin/env python
# -*- encoding:utf-8 -*-
#module :adhai transfer system

import shelve
import os
from sys import argv,exit
import commands as cmd

#3 查询失败，需退出查询

def main():
	fn = argv[1]
	dbFile = argv[2]
	#spid = argv[3]

	if not os.path.exists(dbFile):
		print "%s not exists" % dbFile
		exit(3)

	db = shelve.open(dbFile)
	if db.has_key(fn):
		stat = db[fn]['stat']
	else:
		print "db file has no key [%s]" % fn
		db.close()
		exit(3)

	# if (stat = 1) file in transfer, then check the scp script if running	
	if stat == 1:
		queryCmd = "ps -ef |grep scp |grep %s" % fn
		rstat, ret = cmd.getstatusoutput(queryCmd)
		if rstat == 0  and ret:
			db.close()
			exit(1)
		else:
			db.close()
			db = shelve.open(dbFile)
			stat = db[fn]['stat']
			if stat == 1:
				stat = 2
        db.close()
	exit(stat)

if __name__ == '__main__':
	main()
