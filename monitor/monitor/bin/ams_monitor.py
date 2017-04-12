#!/usr/bin/env python
#-*- encoding:utf8 -*-

import os, sys, datetime, time, pickle, re, ConfigParser, logging
import commands as cmds
import socket
import stat, glob

#初始化log目录，每隔10s输出一次记录到ams.log文件中
def initLog(filename, level=10):
	#创建一个logger
    logger = logging.getLogger()
	#创建一个句柄(handler)，用于写入日志文件
    handler = logging.FileHandler(filename)
	# 定义handler的输出格式
    formatter = logging.Formatter('[%(asctime)s -%(thread)d-%(levelname)s]: %(message)s')
    handler.setFormatter(formatter)
	# 给logger添加handler 
    logger.addHandler(handler)
    logger.setLevel(level)
    return logger

def daemonize(stdin='/dev/null', stdout='/dev/null', stderr='/dev/null'):
    """set daemonize """
    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError, e:
        sys.stderr.write("fork #1 failed (%d) %s\n " %(e.errno, e.strerror))
        sys.exit(0)
        
    os.setsid()
    os.chdir('.')
    os.umask(0)

    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError, e:
        sys.stderr.write("fork #2 failed (%d) %s\n " %(e.errno, e.strerror))
        sys.exit(0)
    
    if not stderr: stderr = stdout
    si = file(stdin, "r")
    so = file(stdout, "w+")
    se = file(stderr, "a+")
    pid = str(os.getpid())
    print "start with pid :[%s]" % pid
    fp = open("pid","w")
    print >> fp, pid
    fp.close()
    sys.stderr.flush()
    
    sys.stdout.flush()
    sys.stderr.flush()
    os.dup2(si.fileno(), sys.stdin.fileno())
    os.dup2(so.fileno(), sys.stdout.fileno())
    os.dup2(se.fileno(), sys.stderr.fileno())

#得到conf配置文件的内容
def confParse(confFile):
    print confFile
	#集合
    confDict = {}
    try:
        cf = ConfigParser.ConfigParser()
        cf.read(confFile)

        confDict['log'] = cf.get("common", "logPath")
        confDict['pName'] = cf.get("common", "processName")
        confDict['core'] = cf.get("common", "corePath")
        confDict['srvId'] = cf.get("common", "serverID")
        confDict['type'] = cf.get("common", "monitorType")
        confDict['out'] = cf.get("common", "outLogPath")
        confDict['gap'] = cf.getint("common", "gapTime")
        confDict['store'] = cf.get("common", "storeFile")
        confDict['cluster'] = cf.get("common", "cluster")
        confDict['module'] = cf.get("common", "module")
        confDict["amsLog"] = cf.get("common", "amsLogPath")     #ams日志
        confDict['es'] = cf.get("common", "esPat")
        confDict['warningA'] = cf.get("warning", "warningPathA")
        confDict['warningB'] = cf.get("warning", "warningPathB")


        return confDict
	#异常返回
    except Exception, e:
        print "Exception:read conf:", str(e)
        return
		
def ams_log(logDir):
    now_time = time.localtime(time.time())
    now_year = time.strftime('%Y', now_time)
    now_month = time.strftime('%m', now_time)
    now_day = time.strftime('%d', now_time)
    ams_name = logDir.replace('YYYY', now_year).replace('MM',now_month).replace('DD',now_day)
    return ams_name

def read_error(errDir):
    com = ""
    print errDir
    if os.path.exists(errDir):
        fp = open(errDir)
        com = fp.read().replace('\n', '|')
        fp.close()
    print com
    com_len = len(com)
    if com_len != 0:
        com = com[:com_len - 1]
    return com

class Ams_monitor:
	#类初始化
    def __init__(self,cfDict,log):
        self.cfDict = cfDict
        self.log = log

        self.stDict = {}        #amslog,leek,date,time,存储
        self.mDict = {}         #hostname,conn,core,pid,cpu,mem
        self.mDict['hostname'] = socket.gethostname()
        self.mDict['conn'] = 0
        self.mDict['core'] = 0
        self.logsize = 0
        self.leek = 0

        self.warnAnum = 0
        self.warnAmsg = ""
        self.warnBnum = 0
        self.warnBmsg = ""
        self.warnCmsg = "other_warning"
        self.warnCnum = 0
        self.content = ""
        self.rsize = 0
        #self.today = str(datetime.date.today())

	#监控ams
    def m_ams(self):    #pid,cpu,mem,core
        #pid,cpu,mem  系统命令
        sysCmd = '''ps aux|awk '{if($11 ~/%s/)print $2,$3,$4}' ''' % self.cfDict["pName"]
        print sysCmd
        try:
            (status, ret) = cmds.getstatusoutput(sysCmd)
            status
            ret
            if status != 0 or not ret:
                self.mDict['pid'] = 0
                self.mDict['cpu'] = 0.0
                self.mDict['mem'] = 0.0
                self.log.error("get app's sysargs failed")
            else:
                var = ret.split()
                self.mDict['pid'] = int(var[0])
                self.mDict['cpu'] = float(var[1])
                self.mDict['mem'] = float(var[2])
        except Exception, e:
			#抛出异常，表示没有执行ams可执行程序
            self.log.error("Exception: get sys info failed, %s" % str(e))
            return
        #conn数不监控

        self.mDict['core'] = 0
        #core
        try:
            for item in os.listdir(self.cfDict['core']):
                if item[:4] != "core":
                    continue
                subpath = os.path.join(self.cfDict['core'], item)
                fstat = os.stat(subpath)
                mode = fstat[stat.ST_MODE]
                if stat.S_ISDIR(mode) == False:
                    m_time = fstat[stat.ST_MTIME]
                    tmp_str = time.strftime("%Y-%m-%d",time.localtime(m_time))
                    now_str = time.strftime("%Y-%m-%d",time.localtime(time.time()))
                    print tmp_str, now_str
                    if tmp_str == now_str:
                        self.mDict['core'] += 1
        except Exception,e:
            self.log.error("Exception: count core num failed! %s" % str(e)) 
        print "self.mDict=[%s]" %(self.mDict)

    def load_info(self):    #备份信息，amslog，leek，error_info，warning_info
        storeDict = {}
        storeFile = self.cfDict['store']
        if os.path.exists(storeFile) and os.path.getsize(storeFile) != 0:
            self.stDict = pickle.load(open(storeFile))
            
        else:
            self.stDict['id'] = 1
            self.stDict['date'] = str(datetime.date.today())
            self.stDict['leek'] = 0
            self.stDict['amslog'] = ams_log(self.cfDict['amsLog'])
        self.com1 = read_error(self.cfDict['warningA'])   #严重告警，read_error读出错误
        self.com2 = read_error(self.cfDict['warningB'])   #一般告警

	#读文件内容
    def read_content(self):
        today = str(datetime.date.today())
        self.now = datetime.datetime.now()
        if today != self.stDict['date']:
            self.log.info("change day[%s-->%s]" %(self.stDict['date'],today))
            self.stDict['leek'] = 0
            self.stDict['id'] = 1
            self.stDict['amslog'] = ams_log(self.cfDict['amsLog'])
            self.stDict['date'] = today

        try:
            fp = open(self.stDict['amslog'], "rb")
            fp.seek(self.stDict['leek'])
        except Exception,e:
            self.log.warning("read log file failed,Error:"+str(e))
            return
        self.rsize = os.stat(self.stDict['amslog'])[stat.ST_SIZE]
        data = fp.read()
        index = data.rfind("\n")
        self.content = data[:index+1]
        self.stDict['leek'] += len(self.content)
        fp.close()

    def logParse(self):     #warning, error,total
        #total 
        com=".*\[warning\].*|.*\[error\].*"
		#正则表达式解析，找出所有的warning信息
        total_res = re.findall(com, self.content, re.M)
        self.warnCnum = len(total_res)
        if self.warnCnum <= 0:
            self.warnAnum = 0
            self.warnAmsg = ""
            self.warnBnum = 0
            self.warnBmsg = ""
            return
        #warning
        wDict = {}
        try:
            if len(self.com1) > 0:
                res = re.findall(self.com1, self.content, re.M)
                self.warnAnum = len(res)
                for msg in res:
                    if wDict.get(msg):
                        wDict[msg] += 1
                    else:
                        wDict[msg] = 1
                self.warnAmsg = sorted(wDict.items(), reverse = True)[0][0]
        except Exception,e:
                self.log.warning("com1 find,Error:"+str(e))
        #error
        wDict = {}
        try:
            if len(self.com2) > 0:
                res = re.findall(self.com2, self.content, re.M)
                self.warnBnum = len(res)
                for msg in res:
                    if wDict.get(msg):
                        wDict[msg] += 1
                    else:
                        wDict[msg] = 1
                self.warnBmsg = sorted(wDict.items(), reverse = True)[0][0]
        except Exception,e:
                self.log.warning("com2 find,Error:"+str(e))
        
        self.warnCnum = self.warnCnum - self.warnAnum - self.warnBnum
        if self.warnCnum < 0:
            self.warnCnum = 0
        self.log.debug("%s:%d,%s:%d,%s:%d" %(self.warnAmsg,self.warnAnum,self.warnBmsg,self.warnBnum,self.warnCmsg,self.warnCnum))

	#写消息
    def write_message(self):
        line = "%s&%s|%s|%0.3f|%0.3f|%d|%d|%d|%d|%s|%d|%s|%d|%s|%s|%s\n" %(
                self.cfDict['type'], self.cfDict['srvId'], self.mDict['pid'], self.mDict['cpu'],
                self.mDict['mem'],self.mDict['core'], self.mDict['conn'], self.rsize,
                self.warnAnum,self.warnAmsg,self.warnBnum,self.warnBmsg,self.warnCnum,self.warnCmsg,
                self.stDict['date'], self.now.strftime('%Y-%m-%d %H:%M:%S'))
        fn = "%s/%s_%s_%s_%s.%06d" % (self.cfDict['out'] , self.cfDict['cluster'], self.cfDict['module'], self.mDict['hostname'], self.now.strftime('%Y%m%d%H%M%S'), self.stDict['id']) 
        fp = open(fn, "w")
        fp.write(line)
        fp.close()
        self.stDict['id'] += 1
        print self.stDict

    def sync_data(self):    #备份：id,date,leek,
        pickle.dump(self.stDict, open(self.cfDict['store'],'w'))


def main():
	#得到配置文件的内容
    cfDict = confParse("../conf/conf")
	#初始化log目录，写入日志文件，log是什么？用户还是目录
    log = initLog(cfDict['log']+'ams.log')
	#info  忽略'start monitor ams'输出
    log.info('start monitor ams')
	#创建监控对象
    monitor = Ams_monitor(cfDict, log)
	#备份信息
    monitor.load_info()

    tm2 = int(time.time())
    while True:
		#读取内容
        monitor.read_content()
		#监控ams
        monitor.m_ams()
        monitor.logParse()
        monitor.write_message()
        monitor.sync_data()

        #每120秒产生一个数据文件
        tm1 = int(time.time())
        if 120-(tm1-tm2)>0:
            time.sleep(120-(tm1-tm2))
        tm2 = int(time.time())

 
if __name__ == "__main__":
    #daemonize(stdout="error.log", stderr="error.log")
    main()
