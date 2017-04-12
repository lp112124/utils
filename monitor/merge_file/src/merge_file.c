#include "hash.h"
#include "merge_file.h"
#include "merge_file_thread.h"

extern conf_t g_conf;
hash_t *g_thread_table;

//获取文件
int cut_file_name(char *src_name, char *prefix, merge_file_list_elm_t *elm)
{
	char *cp1, *cp2, t[2];
	int len;

	if(src_name == NULL || prefix == NULL || elm == NULL)
		return -1;

	len = strlen(src_name);

	if((cp1 = strrchr(src_name, '/')))
	{
		cp1++;
		if((cp2 = strrchr(cp1, '_')))
		{
			snprintf(prefix, cp2 - cp1 + 1, "%s", cp1);
		}
		else
			return -1;
	}
	else
	{
		cp1 = src_name;
		if((cp2 = strrchr(cp1, '_')))
		{
			snprintf(prefix, cp2 - cp1 + 1, "%s", cp1);
		}
		else
			return -1;
	}
	cp2++;
	snprintf(elm->filename, len - (cp1 - src_name) + 1, "%s", cp1);
	/*atoi 字符串*/
	t[0] = *cp2;
	t[1] = '\0';
	elm->over_flag = atoi(t);			//后缀第一位为是否结束标志
	cp2++;

	while (*cp2 == '0' && cp2 < (src_name + len - 1))
	{
		cp2++;
	}
	elm->fileno = strtoul(cp2, NULL, 0);
	elm->offset = 0;
	xLog(XLOG_DEBUG, "%s[%d]: filename[%s],over_flag[%d],fileno[%d],offset[%d].", 
				__func__, __LINE__, elm->filename, elm->over_flag, elm->fileno, elm->offset);

	return 0;
}

//int backup_info_read(prefix_name)
int backup_info_read(char *file_name, uint32 *file_order, uint32 *offset)
{
	char backup_file[512], t_file_name[512];
	int flag = 0;
	uint32 t_file_order = 0, t_offset = 0;
	FILE *fp = NULL;
	
	memset (t_file_name, 0, sizeof(t_file_name));
	snprintf(backup_file, sizeof(backup_file), "%s/%s_dat", g_conf.backup_dir, file_name);
	if (-1 == access(backup_file, F_OK))
	{
		return 0;
	}
	if ((fp = fopen(backup_file, "r")) == NULL)
	{
		xLog(XLOG_WARNING, "%s[%d]: open file[%s] failed, err: %s",
				__func__, __LINE__, backup_file, strerror(errno));
		return -1;
	}

	fscanf (fp, "%s %d %d %d", t_file_name, &t_offset, &t_file_order, &flag);
	if (flag == 0)
	{
		t_file_order++;
		t_offset = 0;
	}
	*file_order = t_file_order;
	*offset = t_offset;
	
	//read file[.//cs_20120907.log_dat],meg[../data/old_src_dir/cs_20120907.log_000023][376117520][0].
	//../data/old_src_dir/cs_20120906.log_000012 0 12 0
	xLog(XLOG_DEBUG, "%s[%d]:read file[%s],msg[%s][%d|%d][%d|%d].", 
		__func__, __LINE__, backup_file, t_file_name, *file_order, t_file_order, *offset, t_offset);
	
	fclose(fp);
	return 0;
}

int do_unusual_file(char *src_dir, char *des_dir)
{
	DIR *dir;
	struct dirent *ptr;
	struct stat buf;
	char dir_name[512];

	if(src_dir == NULL)
	{
		return -1;
	}
	
	dir = opendir (src_dir);
	if (NULL == dir)
	{
		xLog(XLOG_WARNING, "%s[%d]: open dir_path[%s] failed, err: %s",
				__func__, __LINE__, src_dir, strerror(errno));
		return -1;
	}
	
	while ((ptr = readdir(dir)) != NULL)
	{
		if (strcmp(ptr->d_name, "..") && strcmp(ptr->d_name, "."))
		{
			memset(dir_name, 0, sizeof(dir_name));
			snprintf (dir_name, sizeof(dir_name), "%s/%s", src_dir, ptr->d_name);
			stat(dir_name, &buf);
			if (S_ISDIR(buf.st_mode))
			{
				xLog(XLOG_DEBUG, "%s[%d]:is dir[%s].", __func__, __LINE__, dir_name);
				continue;
			}
			move_file_cmd(dir_name, des_dir);
		}
	}
	
	closedir(dir);
	return 0;
}

int merge_file(char *dir_path)
{
	DIR *dir;
	struct dirent *ptr;
	merge_file_thread_t *pth = NULL;
	
	if(dir_path == NULL)
		return -1;

	if (dir_path[strlen(dir_path)-1] != '/')
	{
		dir_path[strlen(dir_path)] = '/';
	}
	dir = opendir (dir_path);
	/* 文件名前缀，即'_'之前的，该值可作为hash源 */
	char prefix_name[255], dir_name[512];
	uint32 file_order = 1, offset = 0;
	
	merge_file_list_elm_t *elm = NULL;
	
	g_thread_table = hash_create(100);
	if(g_thread_table == NULL)
	{
		xLog(XLOG_FATAL, "%s[%d]: hash create failed", __func__, __LINE__);
		return -1;
	}

	/*处理程序异常结束后的文件，将其重新移回到处理目录下*/
	do_unusual_file(g_conf.old_src_dir, g_conf.src_dir);

	for(;;)
	{
		xLog(XLOG_DEBUG, "%s[%d]:path[%s].", __func__, __LINE__, getcwd(NULL, 0));
		dir = opendir (dir_path);
		if (NULL == dir)
		{
			xLog(XLOG_WARNING, "%s[%d]: open dir_path[%s] failed, err: %s",
				__func__, __LINE__, dir_path, strerror(errno));
			continue;
		}
		
		while ((ptr = readdir(dir)) != NULL)
		{
			/* if we find a regular file */
			if (strcmp(ptr->d_name, "..") && strcmp(ptr->d_name, "."))
			{
				/* get file prefix name */
				memset (prefix_name, '\0', sizeof(prefix_name));
				elm = (merge_file_list_elm_t *)malloc(sizeof(merge_file_list_elm_t));

				if(cut_file_name(ptr->d_name, prefix_name, elm))
				{
					xLog(XLOG_WARNING, "%s[%d]: get prefix_name of file[%s] failed", __func__, __LINE__, ptr->d_name);
					continue;
				}
				snprintf (dir_name, sizeof(dir_name), "%s%s", dir_path, elm->filename);
				xLog(XLOG_DEBUG, "%s[%d]: dir_name[%s].", __func__, __LINE__, dir_name);

				/* process this piece of file */
				move_file_cmd(dir_name, g_conf.old_src_dir);
				if((pth = (merge_file_thread_t *)hash_find(g_thread_table, prefix_name)))
				{
					/* insert into worklist */
					//char *elm = strdup(fullfilename);
					if(elm)
					{
						if(merge_file_thread_list_push(pth->worklist, (void *)elm))
						{
							xLog(XLOG_WARNING, "%s[%d]: insert elm[%s] failed", __func__, __LINE__, ptr->d_name);
						}
					}
				}
				else
				{
					//读取备份信息
					file_order = 1;
					offset = 0;
					backup_info_read(prefix_name, &file_order, &offset);
					elm->offset = offset;
					
					/* create a new thread for this type of file */
					if((pth = merge_file_thread_create(prefix_name, file_order)))
					{
						if(hash_insert(g_thread_table, prefix_name, pth))
						{
							xLog(XLOG_WARNING, "%s[%d]: hash_insert succeeded, prefix_name: %s", __func__, __LINE__, prefix_name);
							/* insert into worklist */
							//char *elm = strdup(fullfilename);
							if(elm)
							{
								if(merge_file_thread_list_push(pth->worklist, (void *)elm))
								{
									xLog(XLOG_WARNING, "%s[%d]: insert elm[%s] failed", __func__, __LINE__, ptr->d_name);
								}
							}
						}
					}
					else
						xLog(XLOG_WARNING, "%s[%d]: create new thread for[%s] failed", __func__, __LINE__, prefix_name);
				}
				//释放merge_file_list_elm_t
				free(elm);
				elm = NULL;
			}
		}
		closedir(dir);
		sleep(5);
		//xLog(XLOG_DEBUG, "%s[%d]: no fresh file in working directory[%s]", __func__, __LINE__, dir_path);
	}

	return 0;
}

