/************************************************************
 * 默认头文件
 *
 * Author: Bise
 ***********************************************************/
#ifndef __AS_DEF_H
#define __AS_DEF_H
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/epoll.h>
#include <fcntl.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>
#include <dirent.h>
#include <signal.h>
#include <sys/stat.h>
#include <semaphore.h>
#include <stdarg.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>
#include <ctype.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/file.h>
//#include "xlog.h"

typedef int8_t		int8;
typedef int16_t		int16;
typedef int32_t		int32;
typedef int64_t		int64;
typedef u_int8_t	uint8;
typedef u_int16_t	uint16;
typedef u_int32_t	uint32;
typedef u_int64_t	uint64;

//#define __DEBUG__			//测试时加的

#ifdef __DEBUG__
#define AS_DEBUG	1
#else
#define	AS_DEBUG	0
#endif

#include "xlog.h"

#define FILE_NUM 100
#define NEW_DAY 86280		//24*60*60 - 2 * 60
#define ALL_DAY 86400		//24*60*60

//常用配置项
typedef struct
{
	/*文件路径*/
	char			conf_file[256];			//配置文件路径
	char			log_path[256];			//日志文件路径
	char			base_dir[256];			//基础信息文件路径
	char			current_dir[256];		//生成数据当前目录
	char			history_dir[256];		//生成数据历史目录
	char			script_dir[256];		//脚本放置路径
	int				swap_way;				//分文件方式，1：按天 0：按分或者小时
	char			cut_space;				//切割间隔
	char			cut_time[5];			//切割文件的开始时间
	int				cluster_id;				//机房编号
	int				machine_id;				//模块编号
	int				module_seq;				//模块自增量
			

	/*其他信息*/
	char			c_time[10];				//日期
	uint32			space_time;				//执行的间隔时间
	xlog_stat_t	log_stat;					//日志配置

}conf_t;

#endif
