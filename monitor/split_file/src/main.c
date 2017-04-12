
//���յ��ɼ��������ݣ��ϲ��ļ�����֤�ϲ�������ݺ�ԭʼ�ļ�һ��

#include "extract_file.h"
#include "config.h"

conf_t g_conf;

/*
	��������./extract_file
	�������壺
			-d �����з��ļ�������
			-f �ļ��ľ���·��
			-m ������ʽ	1�������и����¿�ʼ 	2��ִ�нű���������(Ĭ��)  3����ִ�нű���������
			-c �иʽ 1������ʱ���и� 2��������Ƭ(Ĭ��)
*/

int main(int argc, char *argv[])
{
	char conf_file[255], log_file[255], base_file[255], input_file[FILE_NUM][255];
	char sh_info[255];
	int ch = 0, file_num = 0, i = 0, while_num = 0, do_again = 0;
	base_info_t *base_info[FILE_NUM];
	int sm = 2, cut_type = 2;
	static time_t sub_time = time(0);
	
	memset (base_info, '\0', sizeof(base_info));
	memset (sh_info, '\0', sizeof(sh_info));
	
	while ((ch = getopt(argc, argv, "d:f:m:c:")) != -1)
	{
		if (ch == 'd' && strlen(optarg) > 0)
		{
			snprintf (g_conf.c_time, sizeof(g_conf.c_time), "%s", optarg);
		}
		else if (ch == 'f' && strlen(optarg) > 0)
		{
			snprintf (input_file[file_num], sizeof(input_file), "%s", optarg);
			file_num++;
		}
		else if (ch == 'm' && strlen(optarg) > 0)
		{
			sm = atoi(optarg);
		}
		else if (ch == 'c' && strlen(optarg) > 0)
		{
			cut_type = atoi(optarg);
		}
	}
	
	if (g_conf.c_time[0] == '\0')
	{
		get_now_day(g_conf.c_time);
	}
	
	snprintf (conf_file, sizeof(conf_file), "../conf/split_file.conf");
	//�������ļ�
	conf_init();
	if (-1 == conf_read(conf_file, conf_int1_fun))
	{
		xLog(XLOG_FATAL, "%s[%d]:program conf_read failed[%s].", __func__, __LINE__, conf_file);
		return -1;
	}

	snprintf (base_file, sizeof(base_file), "%s/base_info.dat", g_conf.base_dir);	//�����ļ�
	snprintf (log_file, sizeof(log_file), "split_file");				//��־�ļ�
	// ����־�ļ�
	if (open_log(log_file) < 0)
	{
		xLog(XLOG_WARNING, "%s[%d]:open file[%d] failed.", __func__, __LINE__, log_file);
		return -1;
	}

	//С�ڵ������ڵ��ļ�����		todo	
	
	//���ڵ������ڵ��ļ����ļ�����ʱ��Ϊ00:00����		on going
	xLog(XLOG_DEBUG, "%s[%d]:cut_time[%s].", __func__, __LINE__, g_conf.cut_time);
	if (3 != sm)
	{
		snprintf (sh_info, sizeof(sh_info), "build_file.sh %s %s", g_conf.c_time, g_conf.cut_time);
		run_script(sh_info, g_conf.script_dir);
	}
	//���ػ����ļ���Ϣ����ȡ���ļ�����ƫ��ֵ��д���ļ���������ţ�����
	int ret = load_base_file(base_info, input_file, base_file, &file_num, sm);
	if (-1 == ret || 0 == ret)
	{
		xLog(XLOG_DEBUG, "%s[%d]:No need to access files,ret[%d]", __func__, __LINE__, ret);
	}

	while (1)
	{
		time_t ctime = time(0);
		xLog (XLOG_DEBUG, "====================[%d]=======================",while_num++);
		for (i = 0; i < file_num; i++)
		{
			divided_file(base_info[i], cut_type);
		}

		if ((0 == file_num) || (0 == g_conf.swap_way && ctime - sub_time >= g_conf.cut_space))	//��Сʱ���߷����ж��ļ�
		{
			//���¼��� ����ʱ����Ҫ����
			time_t c_time = time(0) - g_conf.space_time;
			char search_time[15] = {0};
			time_to_datetime(c_time, search_time);
			xLog(XLOG_DEBUG, "%s[%d]:search_time[%s].", __func__, __LINE__, search_time);
			snprintf (sh_info, sizeof(sh_info), "build_file.sh %s", search_time);
			r_load_base_file(base_info, base_file, &file_num, sh_info);
			sub_time = ctime;
		}
		else if (1 == g_conf.swap_way)			//�����ж��ļ�
		{
			char t_time[10] = {0};
			get_now_day(t_time);
			if (strcmp(t_time, g_conf.c_time))
			{
				char search_time[15] = {0};
				time_t c_time = time(0) - g_conf.space_time;
				time_to_datetime(c_time, search_time);
				xLog(XLOG_DEBUG, "%s[%d]:search_time[%s].", __func__, __LINE__, search_time);
				snprintf (sh_info, sizeof(sh_info), "build_file.sh %s", search_time);
				int rload_flag = r_load_base_file(base_info, base_file, &file_num, sh_info);
				if (0 == rload_flag)
				{
					snprintf (g_conf.c_time, sizeof(g_conf.c_time), "%s", t_time);
					do_again = 0;
				}
				else
				{
					do_again = 1;
				}
				xLog(XLOG_DEBUG, "%s[%d]: rload_flag[%d], do_agin[%d], g_conf.c_time[%s].",__func__, __LINE__,rload_flag, do_again, g_conf.c_time);
			}
		}

		//д��
		file_num = record_base_info(base_info, base_file, file_num);
		xLog(XLOG_DEBUG, "%s[%d]:begin sleep[%d]s.", __func__, __LINE__, g_conf.space_time);
		sleep (g_conf.space_time);
	}
	reset_base_info(base_info, file_num);
	//�ͷ�base_info_t
	free_base_info(base_info, file_num);
	
	return 0;
}
