
#include "extract_file.h"

extern conf_t g_conf;
FILE *base_fp = NULL;

//读base_file
int read_base_file(base_info_t **base_info, FILE *fp, int sm)
{
	char buff[255];
	char t_file[255] = {0}, t_date[10] = {0};
	uint32 	t_offset = 0, t_seq_num = 0, t_is_over = 0;
	int num1 = 0;
	
	if (fp == NULL)
	{
		return 0;
	}
	
	//将文件中信息加载到内存
	while (base_fp && fgets(buff, 255, base_fp))
	{
		//t_date t_file t_offset t_seq_num is_over
		sscanf (buff, "%s %s %d %d %d", t_date, t_file, &t_offset, &t_seq_num, &t_is_over);
		if (t_file[0] == '\0')
		{
			xLog(XLOG_WARNING, "%s[%d]:load info from base_file is error,info[%s].",__func__, __LINE__,buff);
			continue;
		}

		if (1 == sm)			//第一次启动，偏移值，自增值都为1
		{
			t_offset = 0;
			t_seq_num = 1;
			t_is_over = 1;
		}
		
		if (0 == t_seq_num)		//t_seq_num表示已经发送过全量文件
		{
			xLog(XLOG_DEBUG, "%s[%d]:Not load buff[%s],is_over[%d].", __func__, __LINE__, buff, t_is_over);
			continue;
		}
		base_info[num1] = (base_info_t *) malloc(sizeof(base_info_t));
		snprintf (base_info[num1]->c_date, sizeof(t_date), "%s", t_date);
		snprintf (base_info[num1]->s_file, sizeof(t_file), "%s", t_file);
		base_info[num1]->offset = t_offset;
		base_info[num1]->seq_num = t_seq_num;
		base_info[num1]->is_over = t_is_over;
		memset (buff, '\0', sizeof(buff));
		num1++;
	}
	return num1;
}

//程序刚启动时加载基础信息
int load_base_file(base_info_t **base_info, char input_file[][255],
					char *base_file, int *file_num, int sm)
{
	int i = 0, j = 0, num1 = 0, num2 = 0, ret = 0;;
	
	if (0 != access (base_file, R_OK) && *file_num == 0)
	{
		return -1;
	}
	
	if (0 == access (base_file, R_OK))
	{
		if ((base_fp = fopen(base_file, "r")) == NULL)
		{
			xLog (XLOG_WARNING, "%s[%d]:read file[%s]failed.", __func__, __LINE__, base_file);
		}
	}
	//将文件中信息加载到内存
	num1 = read_base_file(base_info, base_fp, sm);
	if (base_fp)
	{
		fclose (base_fp);
		base_fp = NULL;
	}
	//将输入的文件加载到内存
	num2 = num1;
	for (i = 0; i < *file_num; i++)
	{
		ret = 0;
		if (input_file[i][0] == '\0')
		{
			continue;
		}
		for (j = 0; j < num2; j++)
		{
			if (0 == strcmp(input_file[i], base_info[j]->s_file))
			{
				ret = 1;
				break;
			}
		}
		if (0 == ret)
		{
			base_info[num1] = (base_info_t *) malloc(sizeof(base_info_t));
			snprintf (base_info[num1]->c_date, sizeof(base_info[num1]->c_date), "%s", g_conf.c_time);
			snprintf (base_info[num1]->s_file, sizeof(base_info[num1]->s_file), "%s", input_file[i]);
			base_info[num1]->offset = 0;
			base_info[num1]->seq_num = 1;
			base_info[num1]->is_over = 1;
			num1++;
		}
	}

	*file_num = num1;
	record_base_info(base_info, base_file, num1);
	return num1;
}

//程序到达一定规则时处理信息
int r_load_base_file(base_info_t **base_info, char *base_file, int *file_num, char *shell_info)
{
	int i = 0, j = 0, mem_num = *file_num, base_num = 0, do_again = 0;
	uint8 t_is_over = 0;
	run_script(shell_info, g_conf.script_dir);
	
	if ((base_fp = fopen(base_file, "r")) == NULL)
	{
		xLog (XLOG_WARNING, "%s[%d]:read file[%s]failed.",__func__, __LINE__, base_file);
		return -1;
	}
	
	base_info_t *tmp_base_info[FILE_NUM];
	memset (tmp_base_info, '\0', sizeof(base_info_t));
	base_num = read_base_file(tmp_base_info, base_fp, 0);
	
	//排除文件内容为空状态
	if (0 == base_num)
	{
		xLog(XLOG_DEBUG, "%s[%d]:base_info[%s] is null.", __func__, __LINE__, base_file);
		return 0;
	}
	//文件i中的信息与内存j中的信息比较
	for (i = 0; i < base_num; i++)
	{
		xLog (XLOG_DEBUG, "%s[%d]:[%d][%s][%s][%d][%d][%d].", __func__, __LINE__,
			i,tmp_base_info[i]->c_date, tmp_base_info[i]->s_file,
			tmp_base_info[i]->offset, tmp_base_info[i]->seq_num,tmp_base_info[i]->is_over);
			
		for (j = 0; j < mem_num; j++)
		{
			//文件内容==内存内容，取内存内容
			if (0 == strcmp(tmp_base_info[i]->s_file, base_info[j]->s_file))
			{
				t_is_over = tmp_base_info[i]->is_over;
				xLog(XLOG_DEBUG, "%s[%d]:file name[%s] is same,is_over[%d->%d].",__func__, __LINE__,tmp_base_info[i]->s_file, base_info[j]->is_over, t_is_over);
				memset (tmp_base_info[i], '\0', sizeof(base_info_t));
				memcpy (tmp_base_info[i], base_info[j], sizeof(base_info_t));
				tmp_base_info[i]->is_over = t_is_over;
				do_again++;
				break;
			}
		}
	}
	
	for (i = 0; i < base_num; i++)
	{
		if (base_info[i] == NULL)
		{
			base_info[i] = (base_info_t *) malloc(sizeof(base_info_t));
		}
		memset (base_info[i], '\0', sizeof(base_info_t));
		memcpy (base_info[i], tmp_base_info[i], sizeof(base_info_t));
	}
	
	for (i = base_num; i < mem_num; i++)
	{
		xLog (XLOG_DEBUG, "%s[%d]:begin free.[%d][%s][%s][%d][%d].", __func__, __LINE__,
			i,base_info[i]->c_date, base_info[i]->s_file, 
			base_info[i]->offset, base_info[i]->seq_num);
		if (base_info[i])
		{
			free (base_info[i]);
			base_info[i] = NULL;
		}
	}
	
	*file_num = base_num;
	if (base_fp)
	{
		fclose (base_fp);
		base_fp = NULL;
	}
	free_base_info(tmp_base_info, base_num);
	if (1 == g_conf.swap_way && do_again)			//表示为换天的，还存在于内存相同的文件
	{
		return 1;
	}

	return 0;
}

void free_base_info(base_info_t **base_info, int file_num)
{
	int i = 0;
	for (i = 0; i < file_num; i++)
	{
		if (base_info[i])
		{
			free (base_info[i]);
			base_info[i] = NULL;
		}
	}
}

void reset_base_info(base_info_t **base_info, int file_num)
{
	int i = 0;
	for (i = 0; i < file_num; i++)
	{
		if (base_info[i])
		{
			memset (base_info[i], '\0', sizeof(base_info[i]));
		}
	}
}
//切片间隔 tmp
/*
int divided_by_time(base_info_t *base_info)
{
	int len = 0;
	char *p = NULL;
	FILE *fp_from = NULL, *fp_to = NULL;
	char *file_from = NULL, file_to[512], buff_tmp[1024];
	uint32 now_l = 0, sub_l = 0;
	file_from = base_info->s_file;
	
	//file_to
	p = s_strrchr(base_info->s_file, '/');
	snprintf (file_to, sizeof(file_to), "%s/%s_%06d", g_conf.current_dir, p, base_info->seq_num);
	xLog(XLOG_DEBUG, "file_from[%s],file_to[%s]. [divided_by_time]", file_from, file_to);
	
	if ((fp_from = fopen(file_from, "r")) == NULL || (fp_to = fopen(file_to, "w")) == NULL)
	{
		xLog (XLOG_WARNING, "open file[%s | %s]failed. [divided_by_time]", file_from, file_to);
		return -1;
	}
	
	now_l = base_info->offset;
	fseek (fp_from, 1L*now_l, SEEK_SET);
	
	while (!feof(fp_from))
	{
		memset (buff_tmp, '\0', sizeof(buff_tmp));
		len = fread (buff_tmp, 1, sizeof(buff_tmp), fp_from);
		fwrite (buff_tmp,  1, len, fp_to);
//		fflush (fp_to);
		sub_l += len;
	}
	
	//移动数据
	if (0 == move_file(file_to))
	{
		if (sub_l)
		{
			base_info->offset = now_l + sub_l;
			base_info->seq_num++;
		}		
		xLog (XLOG_DEBUG, "pre_offset[%d],now_offset[%d],sub_offset[%d]. [divided_by_time]",
				now_l, base_info->offset, sub_l);
	}
	fclose(fp_from);
	fclose(fp_to);
	fp_from = NULL;
	fp_to = NULL;
	
	return 0;
}
*/


//对文件切片，cut_type 1：按时间切割 2：按行切割
int divided_file(base_info_t *base_info, int cut_type)
{
	char *p = NULL, *buff = NULL;
	FILE *fp_from = NULL, *fp_to = NULL;
	char *file_from = NULL, file_to[512];
	int32 now_l = 0, end_l = 0, sub_l = 0, fwrite_size = 0, fread_size = 0, done = 0;
	file_from = base_info->s_file;
	
	if (0 == base_info->seq_num)
	{
		xLog(XLOG_DEBUG, "%s[%d]:Cut file[%s] is over.", __func__, __LINE__, base_info->s_file);
		return 0;
	}
	
	//判断文件是否结束
	base_info->seq_num = base_info->is_over == 0 ? 0 : base_info->seq_num;
	//file_to
	p = s_strrchr(base_info->s_file, '/');
	snprintf (file_to, sizeof(file_to), "%s/%d%d%03d_%s_%06d",
		g_conf.current_dir, g_conf.cluster_id, g_conf.machine_id, g_conf.module_seq, p, base_info->seq_num);
	
	if ((fp_from = fopen(file_from, "r")) == NULL)
	{
		xLog (XLOG_WARNING, "%s[%d]:spen file_from[%s]failed.", __func__, __LINE__, file_from);
		base_info->is_over = 0;
	}
	
	if (fp_from)
	{ 
		now_l = base_info->offset;
		fseek (fp_from, 0, SEEK_END);
		end_l = ftell (fp_from);
		sub_l = end_l - now_l;
		buff = (char *)malloc (sizeof(char) * sub_l+1);			//可以优化
		if (buff == NULL)
		{
			xLog(XLOG_WARNING, "%s[%d]: malloc failed.", __func__, __LINE__);
			free(fp_from);
			return -1;
		}
		memset (buff, '\0', sizeof(char)*sub_l+1);
		fseek (fp_from, 1L*now_l, SEEK_SET);
	}
	
	if ((fp_to = fopen(file_to, "w")) == NULL)
	{
		xLog (XLOG_WARNING, "%s[%d]:open file_to[%s]failed.", __func__, __LINE__, file_to);
		if (fp_from)
		{
			fclose (fp_from);
		}
		free (buff);
		return -1;
	}
	if ((done = fread (buff, 1, sub_l, fp_from)) < 0 || done != sub_l)
	{
		xLog(XLOG_WARNING, "%s[%d]:fread file[%s] failed, error: %s",__func__, __LINE__, file_from, strerror(errno));
		if (fp_from)
		{
			fclose (fp_from);
		}
		fclose (fp_to);
		free (buff);
		return -1;
	}

	if (cut_type == 2 && buff != NULL)
	{
		p = NULL;
		p = rindex (buff, '\n');		
		sub_l = p?p-buff+1:0;
	}

	fwrite_size = fwrite (buff, 1, sub_l, fp_to);
	if (fwrite_size < 0 || fwrite_size != sub_l)
	{
		xLog(XLOG_WARNING, "%s[%d]:fwrite file[%s] failed, error: %s", __func__, __LINE__, file_to, strerror(errno));
		if (fp_from)
		{
			fclose (fp_from);
		}
		fclose (fp_to);
		free (buff);
		return -1;
	}
	fflush(fp_to);

	xLog(XLOG_DEBUG, "%s[%d]:file[%s TO %s]cut_type[%d],fread_size[%d],fwrite_size[%d],seq_num[%d],is_over[%d].",
		__func__, __LINE__, file_from, file_to, cut_type, fread_size, fwrite_size, base_info->seq_num, base_info->is_over);
	//移动数据
	if (0 == move_file(file_to))
	{
		if (sub_l && base_info->seq_num)
		{
			base_info->offset = sub_l + now_l;
			base_info->seq_num++;
		}
		xLog(XLOG_DEBUG, "%s[%d]:pre_offset[%d],now_offset[%d],sub_offset[%d].",__func__, __LINE__,now_l, base_info->offset, sub_l);
	}
	
	if (fp_from)
	{	
		xLog(XLOG_DEBUG, "%s[%d]: fclose fp_from", __func__, __LINE__);
		fclose(fp_from);
		fp_from = NULL;
	}
	if (fp_to)
	{
		xLog(XLOG_DEBUG, "%s[%d]: fclose fp_to", __func__, __LINE__);
		fclose(fp_to);
		fp_to = NULL;
	}
	
	if (buff)
	{
		xLog(XLOG_DEBUG, "%s[%d]: free buff", __func__, __LINE__);
		free (buff);
		buff = NULL;
	}
	
	return 0;
}

int record_base_info(base_info_t **base_info, char *base_file, int file_num)
{
	int i = 0, num = 0;
	//将内存中信息写入磁盘文件
	if ((base_fp = fopen(base_file, "w")) == NULL)
	{
		xLog (XLOG_WARNING, "%s[%d]:write file[%s]failed.", __func__, __LINE__, base_file);
		return -1;
	}

	for (i = 0; i < file_num; i++)
	{
		if (0 == base_info[i]->seq_num)
		{
			continue;
		}
		//t_date t_file t_offset t_seq_num
		fprintf (base_fp, "%s %s %d %d %d\n", 
			base_info[i]->c_date, base_info[i]->s_file,
			base_info[i]->offset, base_info[i]->seq_num, base_info[i]->is_over);
		num++;
	}
	
	if (base_fp)
	{
		fclose (base_fp);
		base_fp = NULL;
	}
	return num;
}

int move_file(char *file_name)
{
	char temp[100];
	memset (temp, 0, sizeof(temp));
	sprintf (temp, "mv %s %s", file_name, g_conf.history_dir);
	int ret = system (temp);
	xLog(XLOG_DEBUG, "%s[%d]:system ret[%d].", __func__, __LINE__, ret);
	return (ret == 0 ? 0 : -1);
}

// 打开日志
int open_log(const char *pname)
{
	if (pname == NULL)
	{
		xLog(XLOG_FATAL, "%s[%d]:open log failed(NULL).", __func__, __LINE__);
		return -1;
	}

	if (!xOpenLog(g_conf.log_path, (char *)pname, &g_conf.log_stat))
	{
		xLog(XLOG_FATAL, "%s[%d]:open log failed.", __func__, __LINE__);
		return -1;
	}

    xLog(XLOG_TRACE, "open log success");
    return 0;
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

char *s_strrchr(char *seek_str, char seek_char)
{
	char *p = NULL;
	p = strrchr(seek_str, seek_char);
	p == 0 ? p : p++;
	return p;
}

int run_script(char *sh_info, char *dir)
{
	char temp[100];
	memset (temp, 0, sizeof(temp));
	sprintf (temp, "cd %s;sh %s", dir, sh_info);
	int ret = system (temp);
	xLog(XLOG_DEBUG, "%s[%d]:sh_info[%s],ret[%d]", __func__, __LINE__, temp, ret);
	return (ret == 0 ? 0 : -1);
}

// 取得当前时间
void s_localtime(time_t s, struct tm *tm)
{

    localtime_r(&s, tm);

    tm->tm_mon++;
    tm->tm_year += 1900;
}

int	time_to_datetime(time_t t, char* date)
{
	struct tm tm;
	
	if (t == 0)
	{
		snprintf(date, 32, "00000000 000000");
	}
	else
	{
		s_localtime(t, &tm);
	
		snprintf(date, 32, "%04u%02u%02u %02u%02u", 
					tm.tm_year, tm.tm_mon, tm.tm_mday,
					tm.tm_hour, tm.tm_min);
	}
	
	return 0;
}
