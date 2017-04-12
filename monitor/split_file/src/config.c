
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
	snprintf(g_conf.base_dir, sizeof(g_conf.base_dir), "../data");
	snprintf(g_conf.current_dir, sizeof(g_conf.current_dir), "../data/current");
	snprintf(g_conf.history_dir, sizeof(g_conf.history_dir), "../data/history");
	snprintf(g_conf.script_dir, sizeof(g_conf.script_dir), "../bin");
	snprintf(g_conf.cut_time, sizeof(g_conf.cut_time), "0000");
	g_conf.space_time = 120;
	g_conf.swap_way = 1;
	g_conf.cut_space = 60;
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
		snprintf(g_conf.log_path, sizeof(g_conf.log_path), val);
	}
	else if (strcasecmp(key, "base_dir") == 0)
	{
		snprintf(g_conf.base_dir, sizeof(g_conf.base_dir), val);
	}
	else if (strcasecmp(key, "current_dir") == 0)
	{
		snprintf(g_conf.current_dir, sizeof(g_conf.current_dir), val);
	}
	else if (strcasecmp(key, "history_dir") == 0)
	{
		snprintf(g_conf.history_dir, sizeof(g_conf.history_dir), val);
	}
	else if (strcasecmp(key, "space_time") == 0)
	{
		g_conf.space_time = atoi(val);
	}
	else if (strcasecmp(key, "script_dir") == 0)
	{
		snprintf(g_conf.script_dir, sizeof(g_conf.script_dir), val);
	}
	else if (strcasecmp(key, "cluster_id") == 0)
	{
		g_conf.cluster_id = atoi(val);
	}
	else if (strcasecmp(key, "machine_id") == 0)
	{
		g_conf.machine_id = atoi(val);
	}
	else if (strcasecmp(key, "module_seq") == 0)
	{
		g_conf.module_seq = atoi(val);
	}
	else if (strcasecmp(key, "swap_way") == 0)
	{
		g_conf.swap_way = atoi(val);
	}
	else if (strcasecmp(key, "cut_space") == 0)
	{
		g_conf.cut_space = atoi(val);
	}
	else if (strcasecmp(key, "cut_time") == 0)
	{
		snprintf(g_conf.cut_time, sizeof(g_conf.cut_time), val);
	}
	
}
