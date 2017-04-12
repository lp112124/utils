
#ifndef _EXTRACT_FILE_H
#define _EXTRACT_FILE_H

#include "def.h"

#define F_STAT 1
#define S_STAT 2

//基础文件信息
typedef struct base_info_s
{
	char 	c_date[10];				//当前日期
	char 	s_file[512];			//源文件
	uint32 	offset;					//文件偏移值
	uint32	seq_num;				//自增编号
//	int		file_type;				//文件类型	1：文件名不固定(默认)	2：文件名固定
	uint8	is_over;				//文件是否处理完毕	0：结束		1：未结束
}base_info_t;

//

int load_base_file(base_info_t **base_info, char input_file[][255], 
						char *base_file, int *file_num, int sm);
void free_base_info(base_info_t **base_info, int file_num);
void reset_base_info(base_info_t **base_info, int file_num);

//int divided_by_time(base_info_t *base_info);
int divided_file(base_info_t *base_info, int cut_type);
int write_file(base_info_t *base_info);
int read_base_file(base_info_t **base_info, FILE *fp, int sum);
int record_base_info(base_info_t **base_info, char *base_file, int file_num);
int r_load_base_file(base_info_t **base_info, char *base_file, int *file_num, char *shell_info);
int move_file(char *file_name);

int open_log(const char *pname);
char *s_strrchr(char *seek_str, char seek_char);
void get_now_day(char *c_time);
int run_script(char *sh_info, char *dir);
int	time_to_datetime(time_t t, char* date);
void s_localtime(time_t s, struct tm *tm);

#endif
