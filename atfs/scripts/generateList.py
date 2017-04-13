#!/usr/bin/env python
# -*- encoding:utf-8 -*-
#script: to generate fileList
#author : xuyaoqiang
#date : 2012-10-16

from sys import argv
import os, time,re
import shelve, stat
import commands as cmd

ARGS = 4


def sortFileList(fileList, format=''):
    enum = ('first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh')
    #如果正则表达式有捕捉，则按照正则表达式的捕捉顺序排序
    if format and re.search('[^\\\]\(.+?[^\\\]\)', format):
        for i in xrange(0,len(fileList)):
            m = re.search(format, fileList[i][0])
            if m:
                new_key = ''
                for x in xrange(0,m.lastindex):
                    new_key += m.group(enum[x])
                fileList[i][1] = new_key
        newList = sorted(fileList, key=lambda filename: filename[1])
    else: #按时间顺序排序
        newList = sorted(fileList, key=lambda filename: int(filename[1]))
    return newList

def generateFileList(fileDir, format=''):
    #获取文件名，modified time列表
    regFilter = ''
    if format:
        regex = format
        if regex.find("(?P") >= 0:
            try:
                regex = re.sub(r'\?P<.+?>', '', regex)
            except Exception, e:
                regex = ''
                print "Exception: convert regular express failed:%s" % str(e)
        
        regFilter = '| egrep "%s"' % regex
    #print "regex filter:  %s  " % regFilter

    #检查目录下是否有符合要求的文件
    emptyDir = 'find %s -maxdepth 1 -type f %s  |wc -l' % (fileDir, regFilter)
    (emptyStat, emptyRet) = cmd.getstatusoutput(emptyDir)
    if emptyStat == 0:
        try:
            if int(emptyRet) == 0:
                return
        except ValueError, e:
            print "Exception: %s" % str(e)
            return
    else:
        print "Error:can't run the cmd:[%s]" % emptyDir
        return
    
    #生成文件列表     

    list_cmd = 'stat -c "%%n*%%Y" `find %s -maxdepth 1 -type f  %s`' % (fileDir, regFilter)        
    (status, ret) = cmd.getstatusoutput(list_cmd)
    if status != 0:
        print "generate file list failed. ret=[%s]" % ret
        return 
    else:
        fileList = ret.split()
        
    newList = [filename.split('*') for filename in fileList]

    #对文件列表排序
    sortedList = sortFileList(newList, format)
    return sortedList    

def main():
    if len(argv[0:]) not in (ARGS, ARGS-1):
        print "args is wrong, exit"
	return -1
    fileDir = argv[1]
    dbFile = argv[2]
    if len(argv[0:]) == ARGS:
        pat = argv[3]
    else:
        pat= ''
    db = {}
    if os.path.exists(dbFile):
        try:
            db = shelve.open(dbFile)
        except Exception, e:
            print e
            return 1

    fileList = generateFileList(fileDir, format=pat)
    if fileList:
        newList = []
        if not db:
            for fn, order in fileList:
                newList.append(fn)
        else:
            for fn, order in fileList:
                if (not db.has_key(fn) or db[fn].get("stat") != 0
                    or db[fn].get('ctime', 0) != os.stat(fn)[stat.ST_CTIME] 
                    or  db[fn].get('rsize', 0) != os.stat(fn)[stat.ST_SIZE]):
                        newList.append(fn)

        if newList:
          print ' '.join(newList)

    return 0

if __name__ == "__main__":
    main()
