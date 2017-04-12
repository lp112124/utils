#include <stdlib.h>
#include "hash.h"
#include "merge_file_thread.h"

extern conf_t g_conf;
extern hash_t *g_thread_table;
//extern char Old_src_dir[];

static void *merge_file_thread_proc(void *arg);

merge_file_thread_list_t *merge_file_thread_list_create(size_t size)
{
	merge_file_thread_list_t *list = NULL;
	int ret = 0;
	list = (merge_file_thread_list_t *)malloc(sizeof(merge_file_thread_list_t));
	
	if(list)
	{
		list->content = (void **)malloc(sizeof(void *) * size);
		if(list->content)
		{
			list->size = size;
			list->head = 0;
			list->tail = 0;
			while(size--)
				list->content[size] = NULL;
			pthread_mutex_init(&(list->mutex), NULL);
			/* 
			this semaphore is set to be shared between threads of one process 
			the maxium size is up to 1000
			*/
			ret = sem_init(&list->ipc, 0, 1000);
		}
		else
		{
			free(list);
			list = NULL;
		}
	}

	return list;
}

int merge_file_thread_list_push(merge_file_thread_list_t *list, void *data)
{
	//void *elm = NULL;
	int ret = 0;

	if(list != NULL && data != NULL)
	{
		if(!pthread_mutex_lock(&(list->mutex)))
		{
			list->content[list->tail] = data;
			list->tail = (list->tail + 1) % list->size;
			if(list->head == list->tail)
			{
				void **temp = (void **)malloc(sizeof(void *) * (list->size * 2));
				if(temp == NULL)
				{
					pthread_mutex_unlock(&(list->mutex));
					return -1;
				}
				uint32 i;
				for(i = 0; i < list->size; i++)
				{
					temp[i] = list->content[i];
				}
				//list->size *= 2;
				for(; i < list->size * 2; i++)
				{
					temp[i] = NULL;
				}
				free(list->content);
				list->content = temp;
				list->tail = list->size;
				list->size *= 2;
			}
			/* post a semaphore */
			ret = sem_post(&list->ipc);
			pthread_mutex_unlock(&(list->mutex));
		}
	}

	return 0;
}

void *merge_file_thread_list_pop(merge_file_thread_list_t *list)
{
	void *elm = NULL;
	int ret;

	if(list)
	{
		/* this thread block here */
		while((ret = sem_wait(&list->ipc)) != 0 && errno != EINTR);
			
		if(!pthread_mutex_lock(&(list->mutex)))
		{
			if(list->head != list->tail)
			{
				elm = list->content[list->head];
				list->content[list->head] = NULL;
				list->head = (list->head + 1) % list->size;
			}
			pthread_mutex_unlock(&(list->mutex));
		}
	}

	return elm;
}

void merge_file_thread_list_destroy(merge_file_thread_list_t *list, void (*free_func)(void *))
{
	uint32 i;
	for(i = 0; i < list->size; i++)
	{
		if(list->content[i] != NULL && free_func)
		{
			(*free_func)(list->content[i]);
			list->content[i] = NULL;
		}
	}
	pthread_mutex_destroy(&list->mutex);
	sem_destroy(&list->ipc);
	free(list);
}


merge_file_thread_t *merge_file_thread_create(char *prefix, uint32 file_order)
{
	merge_file_thread_t *pth = NULL;
	pthread_t	tid;
	pth = (merge_file_thread_t *)malloc(sizeof(merge_file_thread_t));
	if(pth)
	{
		snprintf(pth->prefix_name, sizeof(pth->prefix_name), "%s", prefix);
		pth->file_order = file_order;
		pth->worklist = merge_file_thread_list_create(DEF_WORKLIST_SIZE);
		if(pth->worklist)
		{
			pthread_create(&tid, NULL, merge_file_thread_proc, (void *)pth);
			pth->thread_id = tid;
		}
		else
		{
			free(pth);
			pth = NULL;
		}
	}

	return pth;
}

void merge_file_thread_destroy(void *pth)
{
	merge_file_thread_t *p = (merge_file_thread_t *)pth;
	
	if(p)
	{
		merge_file_thread_list_destroy(p->worklist, free);
		p->worklist = NULL;
		free(p);
		xLog(XLOG_DEBUG, "%s[%d]", __func__, __LINE__);
	}
}

#define STR(n) #n

//write_info  	backup_info_write(backup_file, src_filename, total_num, file_order,0);
static int backup_info_write(char *file_name, char *buff)
{
	FILE *fp = NULL;
	if ((fp = fopen(file_name, "w")) == NULL)
	{
		xLog(XLOG_WARNING, "%s[%d]:open file failed, error:%s.", __func__, __LINE__, strerror(errno));
		return -1;
	}
	
	fprintf (fp, "%s", buff);
	fflush(fp);
	fclose (fp);
	return 0;
}

static int merge_file_write(int src_fd, int dest_fd, char *backup_file,
							char *src_filename, uint32 offset, uint32 file_order)
{
	int n, written = 0, done = 0;
	uint32 total_num = 0;
	char buf[1024], msg[1024];
	if (lseek(src_fd, offset, SEEK_SET) < 0)
	{
		xLog(XLOG_WARNING, "%s[%d]:lseek failed, error:%s.", __func__, __LINE__, strerror(errno));
		return -1;
	}
	total_num += offset;
	while(1)
	{
		memset(buf, 0, sizeof(buf));
		n = read(src_fd, buf, sizeof(buf));
		written = 0;
		if(n > 0 && n <= (int)sizeof(buf))
		{
			do{
				if((done = write(dest_fd, buf+written, n - written)) < 0)
				{
					xLog(XLOG_WARNING, "%s[%d]: write file failed, error: %s", __func__, __LINE__, strerror(errno));
					close(src_fd);
					memset (msg, 0, sizeof(msg));
					snprintf (msg, sizeof(msg), "%s %d %d %d", src_filename, total_num, file_order, 1);
					backup_info_write(backup_file, msg);
					return -1;
				}
				
				written += done;
				total_num += written;
				if(written == n)
					break;
			}while(1);
		}
		else if(n == 0)
		{
			close(src_fd);
			break;
		}
		else
		{
			close(src_fd);
			break;
		}
	}
	snprintf (msg, sizeof(msg), "%s %d %d %d", src_filename, total_num, file_order, 0);
	backup_info_write(backup_file, msg);

	return 0;
}

//rm split file
static int split_file_rm(const char *file_name)
{
	if (unlink(file_name) < 0)
	{
		xLog(XLOG_WARNING, "%s[%d]:unlink failed, error:%s.", __func__, __LINE__, strerror(errno));
		return -1;
	}
	xLog(XLOG_DEBUG, "%s[%d]:rm %s.", __func__, __LINE__, file_name);
	return 0;
}

//gz merge_file_gz
static int merge_file_gz(const char *file_name)
{
	int len = 0;
	char *p = NULL, t_file_name[256] = {0};
	if (access(file_name, F_OK) < 0)		//文件是否存在
	{
		xLog(XLOG_WARNING, "%s[%d]:file[%s]not exist, error:%s.", __func__, __LINE__, file_name, strerror(errno));
		return -1;
	}
	
	len = strlen(file_name);
	snprintf (t_file_name, len + 1, "%s", file_name);
	p = strrchr(t_file_name, '/');
	p = p ? p : t_file_name;
	p++;

	if (len <= 1)
	{
		return -1;
	}

	char cmd[1024];
	
	snprintf (cmd, sizeof(cmd), "tar -C %s -czf %s/%s.tar.gz %s; rm %s",
			g_conf.current_dir, g_conf.current_dir, p, p, t_file_name);

	xLog(XLOG_DEBUG, "%s[%d]:cmd[%s].", __func__, __LINE__, cmd);
	if(system(cmd))
	{
		xLog(XLOG_DEBUG, "%s[%d]: cmd[%s] failed, err: %s", __func__, __LINE__, cmd, strerror(errno));
		return -1;
	}
	return 0;
}

//des_dir merge_file		pth->prefix_name
static int merge_file_dir(const char *file_name, char *mv_to_dir, int dir_len)
{
	int len = 0, i = 0, cluster_id = 0, module_id = 0, module_seq = 0, tem = 0;
	char *p1 = NULL, *p2 = NULL, t_file_name[256], service_id[10], module_name[255];
	uint32 s_id = 0;

	snprintf (t_file_name, strlen(file_name) + 1, "%s", file_name);
	len = strlen (file_name);
	
	if ((p1 = strchr (t_file_name, '_')) == (p2 = strrchr (t_file_name, '_')) || p1 == t_file_name
		|| (len = p1 - t_file_name) > 10 || len < 7)
	{
		xLog(XLOG_WARNING, "%s[%d]:file_name[%s] error.", __func__, __LINE__, file_name);
		return -1;
	}

	snprintf (service_id, len + 1, "%s", t_file_name);
	p1--;
	for (i = 0; i < len; i++)
	{
		if (!isdigit(*p1))
		{
			xLog(XLOG_WARNING, "%s[%d]:file_name[%s] error.", file_name);
			return -1;
		}
		p1--;
	}
	s_id = atol(service_id);
	tem = s_id / 1000;
	module_seq = s_id % 1000;
	cluster_id = tem / 1000;
	module_id = tem % 1000;
	//处理分级目录
	switch (module_id)
	{
		case 200:
			snprintf (module_name, sizeof(module_name), "ACCESS_LOG"); break;
		case 201:
			snprintf (module_name, sizeof(module_name), "AMS_LOG"); break;
		case 202:
			snprintf (module_name, sizeof(module_name), "CS_LOG"); break;
		case 203:
			snprintf (module_name, sizeof(module_name), "CC_LOG"); break;
		default:
			xLog(XLOG_WARNING, "%s[%d]:unknown module_id,file_name[%s]", __func__, __LINE__, file_name);
			return -1;
	}
	cluster_id = cluster_id == 99 ? 3 : cluster_id;
	snprintf (mv_to_dir, dir_len, "%s/%02d", module_name, cluster_id);
	xLog(XLOG_DEBUG, "%s[%d]:service_id[%s], mv_to_dir[%s].", __func__, __LINE__, service_id, mv_to_dir);	
	return 0;
}

static int merge_file_thread_check_cache_file(hash_t *file_cache, uint32 *file_order, int dst_fd, merge_file_thread_t *pth, 
		char *backup_file, char *done_pieces_dir, uint32 total_file_num)
{
	char str_fileno[32];
	char src_filename[256];
	char *filename = NULL;
	int src_fd;
	
	while(file_cache->used)
	{
		snprintf(str_fileno, sizeof(str_fileno), "%d", *file_order);

		if((filename = (char *)hash_find(file_cache, str_fileno)))
		{
			/* write merged-file */
			snprintf(src_filename, sizeof(src_filename), "%s", filename);
			src_fd = open(filename, O_RDONLY);
			if(src_fd == -1)
			{
				xLog(XLOG_WARNING, "%s[%d]:error: %s.", __func__, __LINE__, strerror(errno));
				hash_delete(file_cache, str_fileno, free);
				continue;
			}
			if(merge_file_write(src_fd, dst_fd, backup_file, filename, 0, *file_order))
			{
				hash_delete(file_cache, str_fileno, free);
				continue;
			}
			xLog(XLOG_DEBUG, "%s[%d]:do file[%s] finishing,file_order[%d].", __func__, __LINE__, src_filename, *file_order);
			/*处理完后的文件删除或移动文件*/
			if (g_conf.is_rm || split_file_rm(src_filename))
			{
				move_file_cmd(src_filename, done_pieces_dir);
			}

			hash_delete(file_cache, str_fileno, free);
			(*file_order)++;
		}
		else
		{
			if(file_cache->used == 1 && total_file_num == (*file_order - 1))
			{
				if((filename = (char *)hash_find(file_cache, STR(0))))
				{
					/* finish merging file */
					snprintf(src_filename, sizeof(src_filename), "%s", filename);
					src_fd = open(filename, O_RDONLY);
					if(src_fd == -1)
					{
						xLog(XLOG_WARNING, "%s[%d]:error: %s.", __func__, __LINE__, strerror(errno));
						hash_delete(file_cache, str_fileno, free);
						continue;
					}
					if(merge_file_write(src_fd, dst_fd, backup_file, src_filename, 0, 0))
					{
						hash_delete(file_cache, str_fileno, free);
						continue;
					}
					xLog(XLOG_DEBUG, "%s[%d]:do file[%s] finishing,file_order[%d].", __func__, __LINE__, src_filename, *file_order);
					close(dst_fd);
					/*处理完后的文件删除或者移动到另一目录*/
					if (g_conf.is_rm || split_file_rm(src_filename))
					{
						move_file_cmd(src_filename, done_pieces_dir);
					}
					hash_delete(g_thread_table, pth->prefix_name, merge_file_thread_destroy);
					return 1;
				}
				else
				{
					xLog(XLOG_DEBUG, "%s[%d]: only one file in cache", __func__, __LINE__);
				}
			}
			break;
		}
	}
	return 0;
}

static void *merge_file_thread_proc(void *arg)
{
	uint32 file_order = 1;
	merge_file_thread_t *pth = (merge_file_thread_t *)arg;
	hash_t	*file_cache = NULL;
	merge_file_list_elm_t *elm;
	uint32 fileno = 0, offset = 0;
	uint32 total_file_num = 0;
	int fd, finish_flag = 0;
	int src_fd;
	char mergefile_name[512], src_filename[512], backup_file[512], prefix_name[256];

	if(!pth)
	{
		xLog(XLOG_WARNING, "%s[%d]: thread arg invalid", __func__, __LINE__);
		//hash_delete(g_thread_table, pth->prefix_name, merge_file_thread_destroy);
		pthread_exit((void *)-1);
	}
		
	/* for caching files which doesn't enqueue in order of file_no */
	if((file_cache = hash_create(250)) == NULL)
	{
		xLog(XLOG_WARNING, "%s[%d]: hash create failed for file_cache", __func__, __LINE__);
		if(pth)
		{
			//merge_file_thread_destroy(pth);
			hash_delete(g_thread_table, pth->prefix_name, merge_file_thread_destroy);
		}
		pthread_exit((void *)-1);
	}
	/* open merging file */
	snprintf(mergefile_name, sizeof(mergefile_name), "%s/%s", g_conf.current_dir, pth->prefix_name);
	snprintf(prefix_name, sizeof(prefix_name), "%s", pth->prefix_name);
	/* add O_LARGEFILE for handling large file */
	fd = open(mergefile_name, O_CREAT | O_APPEND | O_RDWR | O_LARGEFILE, 0644);
	if(fd == -1)
	{
		hash_delete(g_thread_table, pth->prefix_name, merge_file_thread_destroy);
		pthread_exit((void *)-1);
	}
	
	/* damn it...it's so ugly */
	char date_dir[10], done_pieces_dir[512];
	get_now_day(date_dir);
	snprintf (done_pieces_dir, sizeof(done_pieces_dir), "%s/%s", g_conf.over_src_dir, date_dir);

	/* back_up file for emergency cases */
	snprintf(backup_file, sizeof(backup_file), "%s/%s_dat", g_conf.backup_dir, pth->prefix_name);
	
	/* we begin with this file_no */
	file_order = pth->file_order;

	/* thread cycle */
	for(;;)
	{
		if((elm = (merge_file_list_elm_t *)merge_file_thread_list_pop(pth->worklist)))
		{
			snprintf(src_filename, sizeof(src_filename), "%s/%s", g_conf.old_src_dir, elm->filename);
			//ADD -- 2012.10.8	fileno = elm->fileno;
			//ADD ++ 2012.10.8
			fileno = elm->fileno;
			if (0 == elm->over_flag)
			{
				fileno = 0;
				total_file_num = elm->fileno;
			}
			offset = elm->offset;
/*
			fileno = elm->over_flag == 0 ? 0 : elm->fileno;
			filenum = elm->fileno;
*/
			free(elm);

			xLog(XLOG_DEBUG, "%s[%d]:src_filename[%s],fileno[%d].", __func__, __LINE__, src_filename, fileno);
			if(fileno == file_order)
			{
				/* write into merged-file */
				src_fd = open(src_filename, O_RDONLY | O_EXCL);
				if(src_fd == -1)
				{
					xLog(XLOG_WARNING, "%s[%d]:error: %s.", __func__, __LINE__, strerror(errno));
					continue;
				}
				if(merge_file_write(src_fd, fd, backup_file, src_filename, offset, file_order))
				{
					continue;
				}
				xLog(XLOG_DEBUG, "%s[%d]:do file[%s] finishing,file_order[%d].", __func__, __LINE__, src_filename,file_order);
				if (g_conf.is_rm || split_file_rm(src_filename))
				{
					move_file_cmd(src_filename, done_pieces_dir);
				}
				file_order++;

				finish_flag = merge_file_thread_check_cache_file(file_cache, &file_order, fd, pth, backup_file, done_pieces_dir, total_file_num);

			}
			else if(fileno == 0)
			{
				//ADD ++ 2012.10.08
				if(file_cache->used == 0 && total_file_num == (file_order - 1))
				{
					xLog(XLOG_DEBUG, "%s[%d]:current total_file_num[%d],real filenum[%d].",
						__func__, __LINE__, total_file_num, file_order);
					char str_fileno[32];
					snprintf(str_fileno, sizeof(str_fileno), "%d", file_order);
					src_fd = open(src_filename, O_RDONLY);
					if(src_fd == -1)
					{
						xLog(XLOG_WARNING, "%s[%d]:error: %s.", __func__, __LINE__, strerror(errno));
						hash_delete(file_cache, str_fileno, free);
						continue;
					}
					if(merge_file_write(src_fd, fd, backup_file, src_filename, 0, 0))
					{
						hash_delete(file_cache, str_fileno, free);
						continue;
					}
					/* finish merging file */
					xLog(XLOG_DEBUG, "%s[%d]:do file[%s] finishing,file_order[%d].", __func__, __LINE__, src_filename,file_order);
					close(fd);
					/*处理完后的文件删除或者移动到另一目录*/
					if (g_conf.is_rm || split_file_rm(src_filename))
					{
						move_file_cmd(src_filename, done_pieces_dir);
					}
					hash_delete(g_thread_table, pth->prefix_name, merge_file_thread_destroy);
					//break;
					finish_flag = 1;
				}
				else
				{
					char str_fileno[32];
					snprintf(str_fileno, sizeof(str_fileno), "%d", fileno);
					hash_insert(file_cache, str_fileno, strdup(src_filename));
				}
			}
			else
			{
				if (fileno < file_order)
				{
					xLog(XLOG_WARNING, "%s[%d]:repeat get data,src_filename[%s],fileno[%d].",
						__func__, __LINE__, src_filename, fileno);
					continue;
				}
				char str_fileno[32];
				snprintf(str_fileno, sizeof(str_fileno), "%d", fileno);
				hash_insert(file_cache, str_fileno, strdup(src_filename));
				finish_flag = merge_file_thread_check_cache_file(file_cache, &file_order, fd, pth, backup_file, done_pieces_dir, total_file_num);
			}
			if(finish_flag)
			{
				char t_mergefile_name[512] = {0}, t_history_dir[512] = {0}, mv_to_dir[256];
				char cmd[1024] = {0};

				if (0 == g_conf.is_gz && 0 == merge_file_gz(mergefile_name))
				{
					 snprintf (t_mergefile_name, sizeof(mergefile_name), "%s.tar.gz", mergefile_name);
				}
				else
				{
					snprintf (t_mergefile_name, sizeof(mergefile_name), "%s", mergefile_name);
				}
				
				if (1 == g_conf.end_mark && 1 == g_conf.is_move)	//表示由其他程序移动，并需要.ok
				{
					snprintf(cmd , sizeof(cmd) , "touch %s.ok" , t_mergefile_name);
					if(system(cmd))
					{
						xLog(XLOG_DEBUG, "%s[%d]: cmd[%s] failed, err: %s", __func__, __LINE__, cmd, strerror(errno));
					}
				}
				
				if (0 == g_conf.is_move)
				{
					/*add ++ 9.26 dir*/
					if (g_conf.dir_style)			//当为非0时，目标路径由自己配
					{
						snprintf (t_history_dir, sizeof(t_history_dir), "%s/%s", g_conf.history_dir, date_dir);
					}
					else							//当为0时，目录路径为多级，错误时就放在配置目录后的error下
					{
						if (!merge_file_dir(prefix_name, mv_to_dir, sizeof(mv_to_dir)))
						{
							snprintf (t_history_dir, sizeof(t_history_dir), "%s/%s/%s",
										g_conf.history_dir, mv_to_dir, date_dir);
						}
						else
						{
							snprintf (t_history_dir, sizeof(t_history_dir), "%s/error/%s",
										g_conf.history_dir, date_dir);
						}
					}
					move_file_cmd(t_mergefile_name, t_history_dir);
				}
				xLog(XLOG_DEBUG, "%s[%d]:merge file file[%s,%s] over!.",
					__func__, __LINE__, mergefile_name, t_mergefile_name);
				
				//删除文件
				memset (cmd, 0, sizeof(cmd));
				snprintf (cmd, sizeof(cmd), "rm %s", backup_file);
				if(system(cmd))
				{
					xLog(XLOG_DEBUG, "%s[%d]: cmd[%s] failed, err: %s", __func__, __LINE__, cmd, strerror(errno));
				}		
				break;
			}
		}
	}

	hash_destroy(file_cache, free);
	xLog(XLOG_DEBUG, "%s[%d]: thread exits", __func__, __LINE__);
	pthread_exit((void *)0);
}

