
#ifndef __CONFIG_H__
#define __CONFIG_H__

#include "def.h"

typedef void (*CONF_INIT_FUN)(const char*, const char*);
void conf_int1_fun(const char *key, const char *val);
// 读取配置文件
int conf_read(const char *conf_file, CONF_INIT_FUN conf_fun);
// 配置参数初始化
void conf_init();

#endif // __CONFIG_H__
