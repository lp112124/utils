#ifndef __WORK_LIST_H
#define __WORK_LIST_H

typedef struct work_list_s work_list_t;
struct work_list_s{
	size_t			size;
    size_t			head;
    size_t			tail;
    void			**content;
	pthread_mutex_t mutex;
};

extern work_list_t *work_list_create(size_t);
extern int work_list_push(work_list_t *, void *);
extern void *work_list_pop(work_list_t *);
extern void work_list_destroy(work_list_t *, void (*free_func)(void *));

#endif