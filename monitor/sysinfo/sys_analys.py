#!/usr/bin/env python
from __future__ import division
from sys import exit, argv
import os
import pickle
import time , datetime


REQ_ARGS = 13


stdDict = {'load':16,
            'swap':0.2,
            'openfiles':0.8,
            'process':0.8,    
            'disk':1,
            'netin':100*1024*1024,
            'netout':100*1024*1024}

def main():
    if len(argv) != REQ_ARGS:
        print "please enter the right argv number!"
        exit(1)
    
    os.chdir(os.path.dirname(argv[0]))
    (SERID,
    now_load_l,
    now_allswap,
    now_freeswap , 
    now_diskusage, 
    now_netin,
    now_netout,
    now_openfiles,
    now_maxfiles,
    now_openproc,
    now_maxproc,  
    now_time)  =  argv[1:]
        
    storeFile = "stat/prestat_%s.plk" % SERID
    
    if os.path.isfile(storeFile):
        preStatDict = pickle.load(open(storeFile,'rb'))
    else:
        preStatDict = {'load':1, 'swap':1, 'openfiles':1, 'process':1, 'disk': 1, 'netIn':1, 'netInFlow':0,  'netOut':1, 'netOutFlow':0, 'time':0}
    
    
    
    
    #format :  %Y-%m-%d %H:%M:%S -> timestamp
    now_time = time.mktime(time.strptime(now_time,"%Y-%m-%d %H:%M:%S"))

    
    #load analys
    if float(now_load_l) < stdDict['load']:
        now_load_stat = 1
    else:
        now_load_stat = 0    
        
    if now_load_stat == preStatDict['load']:
        pass
    elif now_load_stat > preStatDict['load']:  
        print "1000001|%s|1"%SERID
    else:
        print "1000001|%s|0"%SERID
        
    preStatDict['load'] = now_load_stat
    

    #swap analys          
    if float(now_freeswap)/float(now_allswap) > stdDict['swap']:
        now_swap_stat = 1
    else:
        now_swap_stat = 0
        
    if now_swap_stat == preStatDict['swap']:
        pass
    elif now_swap_stat > preStatDict['swap']:
        print "1000002|%s|1"%SERID
    else:
        print "1000002|%s|0"%SERID

    preStatDict['swap'] = now_swap_stat



    #openfiles analys
    if int(now_openfiles)/int(now_maxfiles) < stdDict['openfiles']:
        now_files_stat = 1
    else:
        now_files_stat = 0
    if now_files_stat == preStatDict['openfiles']:
        pass
    elif now_files_stat > preStatDict['openfiles']:
        print "1000003|%s|1"%SERID
    else:
        print "1000003|%s|0"%SERID

    preStatDict['openfiles'] = now_files_stat




    #process analys
    if int(now_openproc)/int(now_maxproc) < stdDict['process']:
        now_proc_stat = 1
    else:
        now_proc_stat = 0
    if now_proc_stat == preStatDict['process']:
        pass
    elif now_proc_stat > preStatDict['process']:
        print "1000004|%s|1"%SERID
    else:
        print "1000004|%s|0"%SERID

    preStatDict['process'] = now_proc_stat



    #disk analys
    if int(now_diskusage) < stdDict['disk']:
        now_disk_stat = 1
    else:
        now_disk_stat = 0
    if now_disk_stat == preStatDict['disk']:
        pass
    elif now_disk_stat > preStatDict['disk']:
        print "1000005|%s|1"%SERID
    else:
        print "1000005|%s|0"%SERID

    preStatDict['disk'] = now_disk_stat

    
    # net in analys
    time_diff = now_time - preStatDict['time']
    if time_diff:
        
        if (int(now_netin) - preStatDict['netInFlow'])/time_diff < stdDict['netin']:
            now_netin_stat = 1
        else:
            now_netin_stat = 0
            
        if now_netin_stat == preStatDict['netIn']:
            pass
        elif now_netin_stat > preStatDict['netIn']:
            print "1000006|%s|1"%SERID
        else:
            print "1000006|%s|0"%SERID
            
        preStatDict['netIn'] = now_netin_stat
        preStatDict['netInFlow'] = int(now_netin)
        
          
        

        # net out analys
        if (int(now_netout) - preStatDict['netOutFlow'])/time_diff < stdDict['netout']:
            now_netout_stat = 1
        else:
            now_netout_stat = 0
            
        if now_netout_stat == preStatDict['netOut']:
            pass
        elif now_netout_stat > preStatDict['netOut']:
            print "1000007|%s|1"%SERID
        else:
            print "1000007|%s|0"%SERID
        
        preStatDict['netOut'] = now_netout_stat
        preStatDict['netOutFlow'] = int(now_netout)
       
    preStatDict['time'] = now_time
    
    pickle.dump(preStatDict, open(storeFile,'w'))
    

if __name__ == "__main__":
    main()


