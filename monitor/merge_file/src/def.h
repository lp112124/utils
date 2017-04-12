/************************************************************
 * 默认头文件
 *
 * Author: Bise
 ***********************************************************/
#ifndef __AS_DEF_H
#define __AS_DEF_H
#define _FILE_OFFSET_BITS 64
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

/* added for handling large file */
#ifndef _LARGEFILE_SOURCE
#define _LARGEFILE_SOURCE 
#endif
#ifndef _LARGEFILE64_SOURCE
#define _LARGEFILE64_SOURCE
#endif

#include "xlog.h"

#define FILE_NUM 100
#define NEW_DAY 86280		//24*60*60 - 2 * 60
#define ALL_DAY 86400		//24*60*60

// 常用配置项
typedef struct
{
	/* 文件路径 */
	char			conf_file[256];		// 配置文件路径
	char			log_path[256];		// 日志文件路径
	char			src_dir[256];		// 待处理数据
	char			old_src_dir[256];	// 正在处理的数据
	char			over_src_dir[256];	// 处理完的数据
	char			current_dir[256];	// 正在生成合并文件的目录
	char			history_dir[256];	// 处理完全的数据
	char			backup_dir[256];	//临时文件路径（保存文件合并信息）

	/* 其他信息 */
	int				end_mark;			//结束标志
	char			c_time[10];			// 日期
	uint32			space_time;			// 执行的间隔时间
	xlog_stat_t		log_stat;			// 日志配置
	uint8			is_gz;				//是否压缩
	uint8			is_rm;				//是否删除
	int				is_move;			//是否移动
	int				dir_style;			//文件路径方式

}conf_t;

#endif
