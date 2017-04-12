/************************************************************
 * 日志功能函数
 * Author: Bise
 ***********************************************************/
#ifndef __BS_XLOG_H
#define __BS_XLOG_H

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdarg.h>
#include <string.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>

#define XLOG_NONE     		0x00  	// 不记录任何日志
#define XLOG_FATAL    		0x01  	// 记录FATAL级日志
#define XLOG_WARNING  		0x02  	// 记录WARNING级日志
#define XLOG_NOTICE  		0x04  	// 记录NOTICE级日志
#define XLOG_TRACE    		0x08  	// 记录TRACE级日志
#define XLOG_DEBUG    		0x10  	// 记录DEBUG级日志
#define XLOG_ALL      		0xFF  	// 记录所有日志
#define XLOG_TO_FILE     	0x02 	// 仅输出到文件中
#define XLOG_TO_TTY     	0x01 	// 仅输出到终端屏幕
#define XLOG_TO_ALL     	0x03 	// 同时输出到终端屏幕和文件中

typedef struct {
	int events;               		// 日志记录的级别
	int specific;                	// 其他参数
	int logsize;              		// 日志文件的大小，以K为单位。
} xlog_stat_t;

#ifdef	__cplusplus
extern "C" {
#endif

// 打开日志
bool xOpenLog(const char *path, const char *name, xlog_stat_t *logst);
void xCloseLog();
// 写日志,没有执行打开函数时,会向终端输出
void xLog(const int events, const char *fmt, ...);

#ifdef	__cplusplus
}
#endif

#endif
