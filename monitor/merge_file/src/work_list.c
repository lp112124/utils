#include "work_list.h"

work_list_t *work_list_create(size_t size)
{
	work_list_t *list = NULL;
	list = (work_list_t *)malloc(sizeof(work_list_t));
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
			pthread_mutex_init(&list->mutex, NULL);
		}
		else
		{
			free(list);
			list = NULL;
		}
	}

	return list;
}

int work_list_push(work_list_t *list, void *data)
{
	//void *elm = NULL;

	if(list != NULL && data != NULL)
	{
		if(pthread_mutex_lock(&list->mutex))
		{
			list->content[list->tail] = data;
			list->tail = (list->tail + 1) % list->size;
			if(list->head == list->tail)
			{
				void **temp = (void **)malloc(sizeof(void *) * (list->size * 2));
				if(temp == NULL)
				{
					pthread_mutex_unlock(&list->mutex);
					return -1;
				}
				int i;
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

			pthread_mutex_unlock(&list->mutex);
		}
	}

	return 0;
}

void *work_list_pop(work_list_t *list)
{
	void *elm = NULL;

	if(list)
	{
		if(pthread_mutex_lock(&list->mutex))
		{
			if(list->head != list->tail)
			{
				elm = list->content[list->head];
				list->content[list->head] = NULL;
				list->head = (list->head + 1) % list->size;
			}
			pthread_mutex_unlock(&list->mutex)
		}
	}

	return elm;
}

void work_list_destroy(work_list_t *list, void (*free_func)(void *))
{
	int i;
	for(i = 0; i < list->size; i++)
	{
		if(list->content[i] != NULL && free_func)
		{
			(*free_func)(list->content[i]);
			list->content[i] = NULL;
		}
	}
	free(list);
}