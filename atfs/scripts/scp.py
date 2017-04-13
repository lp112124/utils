#!/usr/bin/env python
# -*- encoding:utf-8 -*-
#script: script to run before scp
#author : xuyaoqiang
#date : 2012-10-16

#from sys import argv
import commands as cmd
import os, time, stat, sys
import shelve, logging

TRANS_DONE_STAT = 0
TRANS_STREAM_STAT = 1
TRANS_FAIL_STAT = 2
LOG_PATH = ''

def initLog(filename, level=10):
    logger = logging.getLogger()
    handler = logging.FileHandler(filename)
    formatter = logging.Formatter('[%(asctime)s -%(thread)d-%(levelname)s]: %(message)s')
    handler.setFormatter(formatter)
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
    print  pid
    sys.stderr.flush()
    
    sys.stdout.flush()
    sys.stderr.flush()
    os.dup2(si.fileno(), sys.stdin.fileno())
    os.dup2(so.fileno(), sys.stdout.fileno())
    os.dup2(se.fileno(), sys.stderr.fileno())
    return

def fileIsOpen(filename, retry=3):
    status = 0
    count = 0
    lsof = "/usr/sbin/lsof %s" % filename

    while not status:
        if count < retry:
            (status, ret) = cmd.getstatusoutput(lsof)
            if status != 0:
                 return
            else:
                print "file [%s] been occupied.retry" % filename
                time.sleep(3)
                count += 1
        else:
            return 1

#对文件md5校验    
def md5File(filename, host, port, log, retry=3, local = True):
    i = 0
    md5_val = ''
    if not local:
        md5_cmd = 'ssh -p %d %s "md5sum %s"' % (port, host, filename)
    else:
        md5_cmd = 'md5sum %s' % filename
        
    while not md5_val:
        if i < retry:           
            i += 1
        else:
            log.warn("file[%s] md5sum failed" % filename)
            return
            
        (status, md5_ret) = cmd.getstatusoutput(md5_cmd)      
        md5_val = md5_ret.split()[0]
        log.debug("host:[%s], md5 file [%s], md5 value[%s]" % (host, filename, md5_val))
        if status != 0:
            md5_val = ''
            log.warn("md5File failed, retry")
            continue
    	else:
            break    
    return md5_val


#传输单个文件     
def scpSingleFile(filename, des, desDir, log, netLimit = 0):
    """
    filename:full-path filename to transfer to des
    des: dict,include key 'host', 'port', 'dir'
    netLimit: to limit speed of file's transfer, 0 means no limit
    """
    status = 1
    count = 1
    basename = os.path.basename(filename) 
    src_md5 = md5File(filename, '', 22, log, retry=3, local=True)
    
    #log.info("scp file[%s] from [%s] to [%s]" % (filename, src['host'], des['host']))
    limit = ' '
    if netLimit:
        limit = '-l %u' % netLimit

    if des['isremote']:
        scp_cmd = 'scp -P %d %s %s %s:%s' % (des['port'], limit,filename, des['host'], desDir)
    else:
        scp_cmd = '\cp -fr %s %s' % (filename, desDir+'/' +basename) #本地传输

    log.debug("scp cmd: %s" % scp_cmd)
    while count < 3:
        (status, ret) = cmd.getstatusoutput(scp_cmd)
        if status == 0:
            des_md5 = md5File(desDir+basename, des['host'], des['port'], log, retry=3, local=True)
            if src_md5 == des_md5 and src_md5:
                return 1
            else:
                log.warn("md5 value is different ,retry")
                count += 1
        else:
            log.info("scp file[%s] failed, retry. ret:(%s) cmd:(%s)" % (filename, ret, scp_cmd))
            count += 1
    return

def main():
    """
    filename: file to transfer
    host: dest-serv host
    port:dest-serv host
    dbFile: to store the file's stat of transfer
    limit: keep the speed of transfer under limit
    postScript: to do the wind-up work
    """

    filename = sys.argv[1]
    
    serv = {}
    serv['host'] = sys.argv[2]
    serv['port'] = int(sys.argv[3])
    serv['dir'] = sys.argv[4]
    serv['isremote'] = 0

    limit = int(sys.argv[5]) 
    dbFile = sys.argv[6]
    dbDir = os.path.dirname(dbFile)
    if not os.path.isdir(dbDir):

        os.mkdir(dbDir)
    postScript = sys.argv[7]
    transDir = serv['dir']+'/trans/'

    db = shelve.open(dbFile, "c")
    
    logFile = dbFile[:-4] + '.log'
    log = initLog(logFile, level=20)
    cTime = os.stat(filename)[stat.ST_CTIME]
    rSize = os.stat(filename)[stat.ST_SIZE]
    scpingStat = {'stat' : TRANS_STREAM_STAT, 
            'ctime':cTime, 
            'rsize':rSize}

    if not db.has_key(filename):
        db[filename] = scpingStat

    fs = db[filename]  # tmp dict

    if (fs['stat'] == TRANS_DONE_STAT and 
       fs['ctime']==os.stat(filename)[stat.ST_CTIME] and
       fs['rsize']==os.stat(filename)[stat.ST_SIZE]):
        log.warn("file has been transfered before!")
        return 0

    db[filename] = fs
    db.sync()

    while True:
        if fileIsOpen(filename):
            fs['stat'] = TRANS_FAIL_STAT
            log.error("file is occupied" % filename)
            break

        mkDestTransDir = "mkdir -p %s" % transDir
        status, ret = cmd.getstatusoutput(mkDestTransDir)
        if status != 0:
            fs['stat'] = TRANS_FAIL_STAT
            log.error("mkDestTransDir [%s] failed" % transDir)
            break

        if not scpSingleFile(filename, serv, transDir, log, netLimit=limit):
            fs['stat'] = TRANS_FAIL_STAT
            log.error("scp file[%s] failed" % filename)
            break

        mvDestFile = "mv %s %s" % (transDir+os.path.basename(filename), serv['dir'])
        status, ret = cmd.getstatusoutput(mvDestFile)
        if status != 0:
            fs['stat'] = TRANS_FAIL_STAT
            log.error("mv file [%s] to dest dir failed" % filename)
            break

        #run post script
        if postScript != 'None':
            status, ret = cmd.getstatusoutput("%s %s" % (postScript, filename))
            log.debug( "run postScript: stat[%d], ret[%s]" % (status, ret))

        fs['stat'] = TRANS_DONE_STAT
        break


    fs['ctime'] = cTime
    fs['rsize'] = rSize
    db[filename] = fs
    log.debug("[%s] finaly stat [%s]" % (filename, str(fs)))
    db.sync()
    db.close()
    return fs['stat']

if __name__ == "__main__":
    daemonize()
    main()
