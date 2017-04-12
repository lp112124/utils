
#include "merge_file.h"
#include "config.h"

conf_t g_conf;

/*
	程序名：./merge_file
	参数含义：
		
*/
int main(int argc, char *argv[])
{	
	char conf_file[255], log_file[255], file_name[255][255];
	//int num = 0;
	
	memset(file_name, '\0', 255*255);
	
	get_now_day(g_conf.c_time);
	snprintf (conf_file, sizeof(conf_file), "../conf/merge_file.conf");
	//读配置文件
	conf_init();
	if (-1 == conf_read(conf_file, conf_int1_fun))
	{
		xLog(XLOG_FATAL, "%s[%d]:program conf_read failed[%s].", __func__, __LINE__, conf_file);
		return -1;
	}
	
	snprintf (log_file, sizeof(log_file), "merge");				//日志文件
	// 打开日志文件
	if (open_log(log_file) < 0)
	{
		xLog(XLOG_WARNING, "%s[%d]:open file[%d] failed.", __func__, __LINE__, log_file);
		return -1;
	}
	
	xLog(XLOG_DEBUG, "=========[%d]============", g_conf.is_move);
	//文件分类
	merge_file(g_conf.src_dir);
	return 0;
}
