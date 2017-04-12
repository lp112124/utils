
#include "config.h"

extern conf_t g_conf;

// 配置参数初始化
void conf_init()
{
#if AS_DEBUG
	g_conf.log_stat.events = XLOG_ALL;
//	g_conf.log_stat.specific = XLOG_TO_ALL;				//调试时使用
	g_conf.log_stat.specific = XLOG_TO_TTY;
#else
	g_conf.log_stat.events = XLOG_FATAL | XLOG_WARNING | XLOG_TRACE | XLOG_DEBUG;
	g_conf.log_stat.specific = XLOG_TO_FILE;
#endif

	snprintf(g_conf.log_path, sizeof(g_conf.log_path), "../logs");
	snprintf(g_conf.current_dir, sizeof(g_conf.current_dir), "../data/current");
	snprintf(g_conf.history_dir, sizeof(g_conf.history_dir), "../data/history");
	snprintf(g_conf.backup_dir, sizeof(g_conf.backup_dir), ".");
	snprintf(g_conf.over_src_dir, sizeof(g_conf.over_src_dir), ".");
	g_conf.is_move = 0;			//0:合并程序自动移，1：由其他程序移动
	g_conf.is_gz = 0;			//0：压缩（默认）	1：不压缩
	g_conf.is_rm = 0;			//0:删除碎片（默认）1：不删除
	g_conf.dir_style = 0;		//0:特殊目录（默认）1：普通目录（history）
	g_conf.end_mark = 0;		//0：不需要结束标志（默认）1：需要		.ok
	
	g_conf.space_time = 120;
}

// 读取配置文件
int conf_read(const char *conf_file, CONF_INIT_FUN conf_fun)
{
	FILE *fp = NULL;

	if ((fp = fopen(conf_file, "r")) == NULL)
	{
		return -1;
	}

	char tmp[1024] = {0};
	int len1 = 0, len2 = 0, max = 0;;
	char *p = NULL, *key = NULL, *val = NULL;
	while (fgets(tmp, 1024, fp))
	{
		if ((p = strchr(tmp, '=')) == 0)
		{
			continue;
		}

		char *p1 = NULL, *p2 = NULL;
		p1 = tmp;
		p2 = p+1;
		tmp[p-p1] = '\0';

		int i = 0;
		while (isspace(p1[i])) i++;
		key = &p1[i];
		if (p1[i] == '#' || p1[i] == '=')
		{
			continue;
		}

		i = 0;
		while (isspace(p2[i])) i++;
		val = &p2[i];

		len1 = strlen(p1);
		len2 = strlen(p2);

		max = len1 > len2 ? len1 : len2;
		i = 1;

		int j = 0, k = 0;
		for (i = 1; i <= max; i++)
		{
			if (j == 0 && (len1 > i) && !isspace(p1[len1-i]))
			{
				p1[len1-i+1] = '\0';
				j = 1;
			}

			if (k == 0 && (len2 > i) && !isspace(p2[len2-i]))
			{
				p2[len2-i+1] = '\0';
				k = 1;
			}
		}
//		if (strchr(key, ' ') || strchr(val, ' '))
		if (strchr(key, ' '))
		{
			continue;
		}
		conf_fun(key, val);
	}

	fclose(fp);
	return 0;
}

//CONF_INIT_FUN conf_int1_fun;回调函数
void conf_int1_fun(const char *key, const char *val)
{
	if (strcasecmp(key, "log_path") == 0)
	{
		snprintf(g_conf.log_path, sizeof(g_conf.log_path), "%s", val);
	}
	else if (strcasecmp(key, "current_dir") == 0)
	{
		snprintf(g_conf.current_dir, sizeof(g_conf.current_dir), "%s", val);
	}
	else if (strcasecmp(key, "history_dir") == 0)
	{
		snprintf(g_conf.history_dir, sizeof(g_conf.history_dir), "%s", val);
	}
	else if(strcasecmp(key, "src_dir") == 0)
	{
		snprintf(g_conf.src_dir, sizeof(g_conf.src_dir), "%s", val);
	}
	else if(strcasecmp(key, "old_src_dir") == 0)
	{
		snprintf(g_conf.old_src_dir, sizeof(g_conf.old_src_dir), "%s", val);
	}
	else if(strcasecmp(key, "over_src_dir") == 0)
	{
		snprintf(g_conf.over_src_dir, sizeof(g_conf.over_src_dir), "%s", val);
	}
	else if(strcasecmp(key, "backup_dir") == 0)
	{
		snprintf(g_conf.backup_dir, sizeof(g_conf.backup_dir), "%s", val);
	}
	else if (strcasecmp(key, "space_time") == 0)
	{
		g_conf.space_time = atoi(val);
	}
	else if (strcasecmp(key, "is_move") == 0)
	{
		g_conf.is_move = atoi(val);
	}
	else if (strcasecmp(key, "is_rm") == 0)
	{
		g_conf.is_rm = atoi(val);
	}
	else if (strcasecmp(key, "is_gz") == 0)
	{
		g_conf.is_gz = atoi(val);
	}
	else if (strcasecmp(key, "dir_style") == 0)
	{
		g_conf.dir_style = atoi(val);
	}
	else if (strcasecmp(key, "end_mark") == 0)
	{
		g_conf.end_mark = atoi(val);
	}
}

// 打开日志
int open_log(const char *pname)
{
	if (pname == NULL)
	{
		xLog(XLOG_FATAL, "open log failed(NULL)");
		return -1;
	}

	if (!xOpenLog(g_conf.log_path, (char *)pname, &g_conf.log_stat))
	{
		xLog(XLOG_FATAL, "open log failed");
		return -1;
	}

    xLog(XLOG_TRACE, "open log success");
    return 0;
}

int move_file_cmd(const char *filename, const char *move_to)
{
	int ret = 0;
	char cmd[1024];
	char old_src_dir[512];

	snprintf(old_src_dir, sizeof(old_src_dir), "%s", move_to);
	if(access(old_src_dir , W_OK) == -1)
	{
		snprintf(cmd , sizeof(cmd) , "mkdir -p %s" , old_src_dir);
		if(system(cmd))
		{
			xLog(XLOG_DEBUG, "%s[%d]: cmd[%s] failed, err: %s", __func__, __LINE__, cmd, strerror(errno));
			ret = 1;
		}
	}
	
	if(ret == 0)
	{
		snprintf(cmd , sizeof(cmd) , "mv %s %s" , filename , old_src_dir);
		xLog(XLOG_DEBUG, "%s[%d]: cmd[%s]" , __func__ , __LINE__ , cmd);
		if(system(cmd))
		{
			xLog(XLOG_DEBUG, "%s[%d]: cmd[%s] failed, err: %s", __func__, __LINE__, cmd, strerror(errno));
		}
	}

	return ret;
}

//获取单天日期
void get_now_day(char *c_time)
{
	char current_time[10] = {0};
	memset (current_time, '\0', sizeof(current_time));
	time_t t;
    struct tm *tm_t;
    time(&t);
	tm_t=localtime(&t);
	snprintf (current_time, sizeof(current_time), "%4d%02d%02d",
				tm_t->tm_year+1900,tm_t->tm_mon+1,tm_t->tm_mday);
	strcpy (c_time, current_time);
}
