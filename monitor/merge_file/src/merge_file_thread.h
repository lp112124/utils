#ifndef __MERGE_FILE_THREAD_H
#define __MERGE_FILE_THREAD_H

#include "def.h"
#include "config.h"

#define DEF_WORKLIST_SIZE 1000

typedef struct merge_file_list_elm_s merge_file_list_elm_t;
struct merge_file_list_elm_s{
	char filename[256];		//文件名
	uint32 fileno;			//文件编号
	uint32 offset;			//文件偏移值
	int    over_flag;		//文件结束标记
};

typedef struct merge_file_thread_list_s merge_file_thread_list_t;
struct merge_file_thread_list_s{
	size_t			size;
	size_t			head;
	size_t			tail;
	sem_t			ipc;
	void			**content;
	pthread_mutex_t mutex;
};

typedef struct merge_file_thread_s merge_file_thread_t;
struct merge_file_thread_s{
	char						prefix_name[256];
	int32						file_order;			//文件编号
	pthread_t					thread_id;
	merge_file_thread_list_t	*worklist;
};

extern merge_file_thread_list_t *merge_file_thread_list_create(size_t);
extern int merge_file_thread_list_push(merge_file_thread_list_t *, void *);
extern void *merge_file_thread_list_pop(merge_file_thread_list_t *);
extern void merge_file_thread_list_destroy(merge_file_thread_list_t *, void (*free_func)(void *));

extern merge_file_thread_t *merge_file_thread_create(char *, uint32);
extern void merge_file_thread_destroy(void *);

#endif
