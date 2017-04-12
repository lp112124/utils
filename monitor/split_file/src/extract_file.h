
#ifndef _EXTRACT_FILE_H
#define _EXTRACT_FILE_H

#include "def.h"

#define F_STAT 1
#define S_STAT 2

//�����ļ���Ϣ
typedef struct base_info_s
{
	char 	c_date[10];				//��ǰ����
	char 	s_file[512];			//Դ�ļ�
	uint32 	offset;					//�ļ�ƫ��ֵ
	uint32	seq_num;				//�������
//	int		file_type;				//�ļ�����	1���ļ������̶�(Ĭ��)	2���ļ����̶�
	uint8	is_over;				//�ļ��Ƿ������	0������		1��δ����
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
