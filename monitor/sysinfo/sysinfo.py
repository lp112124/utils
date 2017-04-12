#!/usr/bin/env python

import socket, time, struct, re, fcntl
import commands as cmds
import pickle, os, sys, datetime
import ConfigParser

dbtype = 11001

def getUpTime(now):
    f = open("/proc/uptime") 
    result = f.read().split()
    f.close() 
    secs = float(result[0]) 
    upsecs = now - secs
    uptime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(upsecs))
    return uptime

def getLoadavg():
    f = open("/proc/loadavg")
    result = f.read().split()
    f.close()
    load_1 = float(result[0])
    return load_1

def getMemInfo():
    f = open("/proc/meminfo")
    mem = {}
    lines = f.readlines()
    f.close()
    for line in lines:
        if len(line) < 2: continue
        name = line.split(':')[0]
        var = line.split(':')[1].split()[0]
        mem[name] = long(var) * 1024.0
    mem['MemUsed'] = mem['MemTotal'] - mem['MemFree'] - mem['Buffers'] - mem['Cached']
    return mem

def getIp(name='eth0'):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  
        
        inet = fcntl.ioctl(s.fileno(), 0x8915, struct.pack('256s', name[:15]))  
        ret = socket.inet_ntoa(inet[20:24])
    except Exception, e:
        ret = 'None'
    return ret  


def getFs():
    fs = {}
    f = open("/proc/sys/fs/file-nr")
    result = f.read().split()
    f.close()

    fs['open'] = int(result[0])
    fs['max'] = int(result[2])
    return fs

def getProc():
    pro = {}
    pro['max'] = int(cmds.getoutput('ulimit -u'))
    pro['task'] = int(cmds.getoutput('ps -ef |wc -l'))
    return pro

def getsocketNum():
    f = open("/proc/net/sockstat")
    stat = f.readlines()[0]
    f.close()

    used = stat.split(":")
    num = int(used[1].split()[1])
    return num

def getServStat(serv="sshd"):
    cmd = "ps -ef |grep -i %s | grep -v grep |wc -l"  % serv
    (stat, ret) = cmds.getstatusoutput(cmd)
    if stat != 0:
        return -1
    else:
        return int(ret)

def getPortStat(port=22):
    cmd = "netstat | grep :%s|wc -l" % port
    (stat, ret) = cmds.getstatusoutput(cmd)
    if stat != 0:
        return -1
    else:
        return int(ret)

def getLogUsers():
    cmd = "users"
    (stat, ret) = cmds.getstatusoutput(cmd)
    if stat != 0:
        return -1
    else:
        return ret

def getNetFlow(name="eth0"):
    f = open("/proc/net/dev")
    lines = f.readlines()
    f.close()

    flowIn = 0
    flowOut = 0
    for line in lines:
        if line.find(name) >= 0:
            cons = line.split(":")
            vals = cons[1].split()
            flowIn = int(vals[0])
            flowOut = int(vals[8])
    return (flowIn, flowOut)

def getDiskStat():
    cmd = "df -lh"
    (stat, ret) = cmds.getstatusoutput(cmd)
    if stat != 0:
        return -1
    else:
        rates = re.findall(" (\d+)% ", ret)
        for rate in rates:
            if int(rate) > 90:
                return 1
        return 0

def getSysInfo(hostname, conf):
    now = time.time()
    localTime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(now))
    servId = conf['sid']

    uptime = getUpTime(now)

    load1 = getLoadavg()

    meminfo = getMemInfo()

    ip = getIp(name=conf['eth'])


    netIn, netOut = getNetFlow(name=conf['eth']) 


    fs = getFs()

    proc = getProc()

    socknum = getsocketNum()

    stat = {}
    stat["mysql"] = getServStat(serv="mysqld")
    stat["httpd"] = getServStat(serv="httpd")
    stat["sshd"] = getServStat(serv="sshd")

    users = getLogUsers()

    diskStat = getDiskStat()


    #type&host|load|meminfo|disk|ip|ip2|ip_net|ip2_net|fs|proc|socknum|stat|users|localtime|uptime
    line = "%d&%d|%s|%0.2f|%0.2f|%0.2f|%0.2f|%0.2f|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s" % (dbtype, 
            	servId, hostname, load1, meminfo['MemTotal']/(1024*1024), meminfo['MemFree']/(1024*1024), meminfo['SwapTotal']/(1024*1024), meminfo['SwapFree']/(1024*1024),
            diskStat, ip, netIn, netOut, fs['open'], fs['max'], proc['task'], proc['max'], socknum, stat["mysql"], 
            stat['httpd'], stat['sshd'], users, localTime, uptime)

    return line


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


def confParse(confFile):
    confDict = {}

    cf = ConfigParser.ConfigParser()   
    cf.read(confFile)

    confDict['eth'] = cf.get("common", "eth")
    confDict['data'] = cf.get("common", "dataPath")
    confDict['sid'] = cf.getint("common", "servId")
    confDict['cluster'] = cf.get("common", "cluster")
    confDict['store'] = cf.get("common", "store")
    
    return confDict

    
def main():
    cfDict = confParse("../conf/conf")
    storeFile = cfDict['store']
    cluster = cfDict['cluster']
    date = str(datetime.date.today())
    store = {'num':1, 'date':date}

    if os.path.exists(storeFile):
        store = pickle.load(open(storeFile))
    
    

    hostname = socket.gethostname()
    
    while 1:
        now = datetime.datetime.now()
        today = str(datetime.date.today())
        if today != store['date']:
            store['num'] = 1
            store['date'] = today
        sysinfo =getSysInfo(hostname, cfDict)
        fn = "%s/%s_%s_%s_%s.%06d" % (cfDict['data'], cluster, 'sysinfo', hostname, now.strftime('%Y%m%d%H%M%S'), store['num'])
        fp = open(fn, "w")
        fp.write(sysinfo)
        fp.close()
        store['num'] += 1
        pickle.dump(store, open(storeFile, "w"))
        time.sleep(120)



if __name__ == "__main__":
    daemonize(stdout="error.log", stderr="error.log")
    main()
