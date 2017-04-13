#!/usr/bin/env python
# -*- encoding:utf-8 -*-
#module :adhai transfer system
#author : xuyaoqiang
#date : 2012-06-04
import sys, os, threading, ConfigParser, time, logging
from optparse import OptionParser
import commands as cmd
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
import smtplib
import pdb

logLevel = {'debug':10, 'info':20, 'warn':30, 'error':40}
TRANS_DONE_STAT = 0
TRANS_STREAM_STAT = 1
TRANS_FAIL_STAT = 2


def sendMail(to_str, to_list, taskName):
    msg = MIMEText(to_str, 'plain', 'utf-8')
    msg['Subject'] ='bx监控:'+ taskName 
    msg['From'] = 'bx监控'
    msg['To'] = ';'.join(to_list)
    
    try:
        smtp = smtplib.SMTP(r'smtp.adpanshi.com')
        smtp.ehlo()
        smtp.login("monitor@adpanshi.com", "1BR7#an-Mk")
        smtp.sendmail('monitor@adpanshi.com', to_list, msg.as_string())
        smtp.close()
        return 0
    except Exception, e:
        return -1


def initLog(filename, logger, level=10):
    handler = logging.FileHandler(filename)
    formatter = logging.Formatter('[%(asctime)s -%(thread)d-%(levelname)s]: %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(level)
    return logger


def getServInfo(addr, localhost='' ,port=22):
    """
    get the serv info by addr format host:dir or dir
    if find the ':', then think it's a remote serv
    otherwise, is a local server
    """
    info = {}
    if addr.find(":") < 0:
        info['isremote'] = 0
        info['host'] = localhost
        info['dir'] = addr+'/'
    else:
        info['isremote'] = 1
        val = addr.split(':')
        info['host'] = val[0]
        info['dir'] = val[1]+'/'
    info['port'] = port

    return info

    
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

def getOptions(args, conf):
    """
    get the conf of the task
    """

    p = OptionParser()
    mailList = conf['mail']

    p.add_option("-s", "--src", type="string", action="store", dest="src", help="source host and directory")
    p.add_option("-d", "--des", type="string", action="store", dest="des", help="destion host and directory")
    p.add_option("-1", "--port1", type="int", action="store", dest="port1", default=22, help="remote login src port num")
    p.add_option("-2", "--port2", type="int", action="store", dest="port2", default=22, help="remote login des port num")
    p.add_option("-p", "--scp_port", type="int", action="store", dest="target", default=22, help="remote scp port")
    p.add_option("-l", "--limit", type="int", action="store", dest="limit", default=0, help="rate limit")
    p.add_option("-f", "--format", type="string", action="store", dest="format", default='', help="format of the file name, regix ")
    p.add_option("-z", "--zip", type="string", action="store", dest="zip", help="zip the file then transfer")
    p.add_option("-r", "--retry", type="int", action="store", dest="retry", default=3, help="retry times")
    p.add_option("-g", "--gap", type="float", action="store", dest="gap", default= 60, help="wait  till next trans") 
    p.add_option("--notOrder", action="store_false", dest="order", default=True, help="trans files ordered")
    p.add_option("--preScript", type="string", action="store", dest="prs",default=None, help= "Script before transfer")
    p.add_option("--srcPostScript", type="string", action="store", dest="srcPos", default="rm_file.sh", help="Script after transfer")
    p.add_option("--desPostScript", type="string", action="store", dest="desPos", default=None,help="Script after transfer")
    p.add_option("--store",  type = 'string', action="store", dest="store", help="store file list ")
    p.add_option("--transScript", type="string", action="store", dest="ts",default="scp.py", help="script to transfer")
    p.add_option("--generateScript", type="string", action="store", dest="gs",default="generateList.py", help="script to transfer")
    p.add_option("--statScript", type="string", action="store", dest="ss", default="stat.py",help="script to transfer")
    p.add_option("--mail",  type = 'string', action="store", dest="mail",  default=mailList, help="mail list for monitor.")
    p.add_option("--srcScriptPath", type="string", action="store", dest="ssp", help="")
    p.add_option("--desScriptPath", type="string", action="store", dest="dsp", help="")
    p.add_option("--ctrHost", type="string", action="store", dest="localhost", help= "")
    p.add_option("--queryGap", type="float", action="store", dest="queryGap", default=1, help= "")
    p.add_option("--queryTimeOut", type="float", action="store", dest="queryTimeOut", default=3600,help= "")
    


    (options, args) = p.parse_args(args)
    
    if options.srcPos == "None":
        options.srcPos = None
    return options
    
def getGlobalConf(conf):
    common = {}
    common['log'] = conf.get("common", "logger")
    common['level'] = conf.get("common", "log_level")
    common['cluster'] = conf.get("common", "cluster")
    common['mail'] = conf.get("common", "mailList")
    common['sid'] = conf.get("common", "servid")
    common['script'] = conf.get("common", "scriptPath")

    return common
    

def mkDir(addr, dire,log, retry=3):
    """  make dir  """

    count = 0
    status = 1
    if dire.find('%') >= 0:
        dire = time.strftime(dire,time.localtime(time.time()))
    if addr['isremote']: 
        mkdir_cmd = 'ssh -p %d %s "mkdir -p %s"' % (addr['port'], addr['host'], dire)
    else:
        mkdir_cmd = 'mkdir -p  %s' % dire
    while  status != 0:
        if count < retry:
            (status, ret) = cmd.getstatusoutput(mkdir_cmd)
            if status == 0:
                log.info("make dir [%s] success" % dire)
                return 1
            else:
                log.warn("make dir [%s] failed.[%s] count: %d. retry" % (dire, ret, count))
                time.sleep(3)
                count += 1
        else: 
            log.error("make dir [%s] failed ")
            return    

def generalRun(serv, to_run, log):
    """
    run the shell cmd in local or remote server
    """
    if serv['isremote']:
        general_cmd = "ssh -p %d %s '%s'" % (serv['port'], serv['host'], to_run)
    else:
        general_cmd = to_run
    log.debug("run cmd[%s]" % general_cmd)
    try:
        (status, ret) = cmd.getstatusoutput(general_cmd)
    except Exception, e:
        log.error("Exception(%s): rm cmd:[%s].ret[%s]" % (str(e), general_cmd, ret))
        time.sleep(1)
        return (-1, "Exception")
    return (status/256, ret)


            
def transFile(conf, content, name, log):
    """
    conf: the main process config
    conten: the config options of task
    name: name of transfer task
    """

    log.info("start process %s task" % name)
    args = content.split()
    options = getOptions(args, conf)
    
    mailList = options.mail.split(';')
    dbFile = options.store
    limit = options.limit
    localScriptPath = conf['script']
    log.info("dbFile=%s limit=%s localScriptPath=%s" % (dbFile, limit, localScriptPath))

    srcScriptPath = options.ssp
    desScriptPath = options.dsp

    transScript = options.ts
    generateScript = options.gs
    statScript = options.ss

    preScript = options.prs
    srcPostScript = options.srcPos
    desPostScript = options.desPos
    
      
    src = getServInfo(options.src, localhost=options.localhost, port=options.port1)
    des = getServInfo(options.des, localhost=options.localhost, port=options.port2)
    local = {'isremote':0}

    log.info("src=%s des=%s srcScriptPath=%s desScriptPath=%s transScript=%s \
                generateScript=%s statScript=%s preScript=%s srcPostScript=%s desPostScript=%s"
                % (src, des, srcScriptPath, desScriptPath, transScript, 
                   generateScript, statScript, preScript, srcPostScript, desPostScript))
    if (not mkDir(src, srcScriptPath, log) and
        not mkDir(des, desScriptPath, log)):
        return 1
    
    # in the order: script-name, serv, path
    scriptList =    [(transScript, src, srcScriptPath),
                    (generateScript, src, srcScriptPath),
                    (statScript, src, srcScriptPath),
                    (preScript, src, srcScriptPath),
                    (srcPostScript, src, srcScriptPath),
                    (desPostScript, des, desScriptPath) 
                    ]

    #transfer the script to the serv and make it executeable
    for script, srv, path in scriptList:
        if not script:
            continue
        if srv['isremote']:
            deployScirptCmd = "scp -P %d %s %s:%s" % (srv['port'], localScriptPath+script, srv['host'], path)
        else:
            deployScirptCmd = "cp %s %s" % (localScriptPath+script, path)
        log.info("%s %s %s" % (script, srv, path))
        log.info("start process %s task" % deployScirptCmd)
        stat, ret =  generalRun(local, deployScirptCmd, log)
        if stat != 0:
            log.error("scp script [%s] failed, error(%s)" % (script, ret))
            return

        chmodCmd = "chmod +x %s" % (path+script)
        stat, ret = generalRun(srv, chmodCmd, log)
        if stat != 0:
            log.error("change mod of script[%s] failed.error(%s)" % (script, ret))
            return


    #main loop     
    while True:
        # run pre script before transfer
        if options.prs:
            preCmd = "%s %s" % (srcScriptPath+preScript, src['dir'])
            log.debug("run cmd [%s]" % preCmd)
            stat, ret = generalRun(src, preCmd, log)
            if stat != 0:
                log.error("run preScript error! error[%s]" % ret)
                time.sleep(options.gap)
                continue

        # generate the file list to transfer
        generateListCmd = "%s %s %s %s" % (srcScriptPath+generateScript, src['dir'], dbFile, options.format)
        stat, ret = generalRun(src, generateListCmd, log)
        if stat != 0:
            log.error("run generateFilelistScript error! error[%s]" % ret)
            time.sleep(10)
            continue
        if not ret:
            log.info("empty dir, sleep %d seconds, retry.[%s]" % (options.gap, ret))
            time.sleep(options.gap)
            continue

        fileList = ret.split()
        log.debug("fileList: [%s]" % ret) 

        for filename in fileList:
            log.info("start transfer file[%s]." % filename)
            fileBase = os.path.basename(filename)
            transCmd = "%s %s %s %d %s %d %s %s"  % (srcScriptPath+transScript, filename, des['host'], options.target, des['dir'], 
                            limit, dbFile,srcPostScript and srcScriptPath+srcPostScript or 'None')
            stat, ret = generalRun(src, transCmd, log)
            if stat != 0:
                log.error("run transScript error.error(%s)" % ret)
                break
            else:
                try:
                    tpid = int(ret)
                except ValueError, e:
                    log.error("cant get the scp pid, retry")
                    break

            tstat = TRANS_STREAM_STAT
            statCmd = "%s %s %s" % (srcScriptPath+statScript, filename, dbFile)
            queryStart = time.time()
            while True:
                now = time.time()
                if (now - queryStart) > options.queryTimeOut: # if timeout,then kill the transfer process,and set trans_fail stat
                    stat, ret = generalRun(src, "kill %d" % tpid, log)
                    if stat == 0:
                        tstat = TRANS_FAIL_STAT
                        break

                time.sleep(options.queryGap)
                tstat, ret = generalRun(src, statCmd, log)
                if tstat == TRANS_DONE_STAT or tstat == TRANS_FAIL_STAT:
                    break

                log.debug("The file is in transfer")
                time.sleep(2)

            if tstat == TRANS_DONE_STAT:
                log.info("scp file successfully")
            elif tstat == TRANS_FAIL_STAT:
                log.warn("scp file failed!")
                if options.order:  
                    break
                else:
                    continue
            else:
                log.error("unkown transfer stat, check the prog")
                
            if desPostScript:
                postCmd = "%s %s" % (desScriptPath+desPostScript, des['dir']+fileBase)
                generalRun(des, postCmd, log)
        
        time.sleep(options.gap)

    
class transThread(threading.Thread):

    def __init__(self, globalConf, content, name):
        threading.Thread.__init__(self, name=name)
        self.name = name
        self.content = content
        self.conf = globalConf
        levelValue = self.conf['level']
        
        log = logging.getLogger(name)
        self.log = initLog(self.conf['log']+name+'.log', log, level=logLevel[levelValue])
    def run(self):
        transFile(self.conf, self.content, self.name, self.log)

def main():
    daemonize(stdout='ats.log', stderr='ats.log')
    #pdb.set_trace()
    threads=[]
    conf = ConfigParser.ConfigParser()
    conf.read("../conf/conf")
    globalConf = getGlobalConf(conf)
    taskConf = conf.items('task') 
    mailList = globalConf["mail"].split(';')

    try:    
        for name, content in taskConf:
            t = transThread(globalConf, content, name)
            threads.append(t)
        for i in range(len(threads)):
            threads[i].start()
        while 1:
            for i in range(len(threads)):
                threads[i].join(300)
                if not threads[i].isAlive():
                    sendMail("thread quit name:[%s]" % str(threads[i].getName()), mailList, globalConf['cluster'])
            time.sleep(30)
    except Exception, e:
        print "Exception, bx crash! "
        sendMail("Exception:%s.bx quit!" % str(e), mailList, globalConf['cluster'])
    

if __name__ == "__main__":
    main()
