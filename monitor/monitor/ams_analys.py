#!/usr/bin/env python
#-*- encoding:utf8 -*-

import sys,time,os,stat,types
import commands
import pickle
import string
MAX_WARN_NUM = 3
[MAXA, MAXB, MAXC] = [20000,1,100]  #A一般告警的个数，B是严重告警个数，C是其他告警信息个数


def main():
    mStatDict={}
    srvId = sys.argv[1]
	#读取命令行参数
    mStatDict['pid'] = int(sys.argv[2])
    mStatDict['cpu'] = float(sys.argv[3])
    mStatDict['mem'] = float(sys.argv[4])
    mStatDict['core'] = int(sys.argv[5])
    mStatDict['conn'] = int(sys.argv[6])
    mStatDict['size'] = int(sys.argv[7])
    mStatDict['warnAnum'] = int(sys.argv[8])
    mStatDict['warnAmsg'] = sys.argv[9]
    mStatDict['warnBnum'] = int(sys.argv[10])
    mStatDict['warnBmsg'] = sys.argv[11]
    mStatDict['warnCnum'] = int(sys.argv[12])
    mStatDict['warnCmsg'] = sys.argv[13]
    mStatDict['date'] = sys.argv[14]
	
    #print "srvId：%s" % srvId
    
    os.chdir(os.path.dirname(sys.argv[0]))
    #print "date:%s" % mStatDict['date']

    storeFile = "stat/ams_%s.plk" % srvId
    #如果文件不存在，就创建文件
    if os.path.exists(storeFile):
        oldStatDict = pickle.load(open(storeFile))
    else:
        oldStatDict = dict.fromkeys(["pid", "cpu", "mem", "core", "conn", "warAnum", "warBnum", "warCnum", "flag", "H"], 0)
        oldStatDict['size'] = [0]
        oldStatDict['date'] = mStatDict['date']


    #recover stat  对比
    if mStatDict['pid'] == 0 and oldStatDict['pid'] > 0:#表示pid出现异常
        print "1102021|%s|0" % srvId
        oldStatDict['pid'] = -1

    if mStatDict['pid'] != oldStatDict['pid'] and mStatDict['pid'] > 0:
        if oldStatDict['pid'] < 0:
            print "1102021|%s|1" % srvId
        else:
            print "1102020|%s|0" % srvId
        oldStatDict['pid'] = mStatDict['pid']


    if mStatDict['cpu'] > 50:
        if oldStatDict['cpu'] == (MAX_WARN_NUM-1):
            print "1102001|%s|0|ams进程占用cpu连续三次超过%%%50" % srvId           
        oldStatDict['cpu'] += 1
    else:
        if oldStatDict['cpu'] > (MAX_WARN_NUM-1):
            print "1102001|%s|1" % srvId   
        oldStatDict['cpu'] = 0


    if mStatDict['mem'] > 80:
        if oldStatDict['mem'] == (MAX_WARN_NUM-1): #warn
            print "1102002|%s|0" % srvId
        oldStatDict['mem'] += 1
    else: #recover
        if oldStatDict['mem'] > (MAX_WARN_NUM-1): 
            print "1102002|%s|1" % srvId
        oldStatDict['mem'] = 0


    if mStatDict['conn'] > 100:
        if oldStatDict['conn'] == (MAX_WARN_NUM-1):
            print "1102005|%s|0" % srvId
        oldStatDict['conn'] += 1
    else: 
        if oldStatDict['conn'] > (MAX_WARN_NUM-1):
            print "1102005|%s|1" % srvId
        oldStatDict['conn'] = 0

    if mStatDict['size'] == oldStatDict['size'][-1]:
        oldStatDict['size'].append(mStatDict['size'])
        if len(oldStatDict['size']) == MAX_WARN_NUM*2:
            print "1102006|%s|0" % srvId
    else:
        if len(oldStatDict['size']) >= MAX_WARN_NUM*2:
            print "1102006|%s|1" % srvId    #事件编号|srvId|1：正常 0：异常
        oldStatDict['size'] = [mStatDict['size']]


    #one time stat
    if mStatDict['core'] > oldStatDict['core'] and mStatDict['date'] == oldStatDict['date'] :
        print "1102003|%s|0" % srvId
    oldStatDict['core'] = mStatDict['core']

    #当前小时
    curr = time.strftime('%H',time.localtime(time.time()))

    if oldStatDict['H'] != curr:
        oldStatDict['warAnum'] = mStatDict['warnAnum']
        oldStatDict['warBnum'] = mStatDict['warnBnum']
        oldStatDict['warCnum'] = mStatDict['warnCnum']
        oldStatDict['flag'] = 0
        if oldStatDict['warAnum'] >= MAXA:
            #事件框架会根据print输出的异常，对异常是否发送邮件或短信
            print "1102010|%s|0|%s:%d" %(srvId, mStatDict['warnAmsg'], oldStatDict['warAnum'])
            #已经发送邮件
            oldStatDict['flag'] = 1
        oldStatDict['H'] = curr
    else :
        oldStatDict['warAnum'] = oldStatDict['warAnum'] + mStatDict['warnAnum']
        if oldStatDict['warAnum'] >= MAXA and oldStatDict['flag'] == 0:
            #事件框架会根据print输出的异常，对异常是否发送邮件或短信
            print "1102010|%s|0|%s:%d" %(srvId, mStatDict['warnAmsg'], oldStatDict['warAnum'])
            #已经发送邮件
            oldStatDict['flag'] = 1

		
    if mStatDict['warnBnum'] > MAXB:
        print "1102011|%s|0|%s:%d" %(srvId, mStatDict['warnBmsg'], mStatDict['warnBnum'])
    if mStatDict['warnCnum'] > MAXC:
        print "1102012|%s|0|%s:%d" %(srvId, mStatDict['warnCmsg'], mStatDict['warnCnum'])   # %s:%d  表示出现异常的具体情况
    oldStatDict['date'] = mStatDict['date'] 

        
    pickle.dump(oldStatDict, open(storeFile, "w"))

  

if __name__ == "__main__":
    main()
