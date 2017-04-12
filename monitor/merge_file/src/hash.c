#include "hash.h"

/* hash key */
static unsigned htable_hash(const char *s, unsigned size)
{
    unsigned long h = 0;
    unsigned long g;

    /*
     * From the "Dragon" book by Aho, Sethi and Ullman.
     */

    while (*s) {
	h = (h << 4U) + *s++;
	if ((g = (h & 0xf0000000)) != 0) {
	    h ^= (g >> 24U);
	    h ^= g;
	}
    }
    return (h % size);
}

/* macro for insert element into hash_t */
#define htable_link(table, element) { \
     hash_info_t **_h = table->data + htable_hash(element->key, table->size);\
    element->prev = 0; \
    if ((element->next = *_h) != 0) \
		(*_h)->prev = element; \
    *_h = element; \
    table->used++; \
}

/* htable_size - allocate and initialize hash table */
static void htable_size(hash_t *table, unsigned size)
{
    hash_info_t **h;

    size |= 1;

    table->data = h = (hash_info_t **)malloc(size * sizeof(hash_info_t *));
    table->size = size;
    table->used = 0;

	/* zero memory */
    while (size-- > 0)
		*h++ = 0;
}

hash_t *hash_create(int size)
{
	hash_t *table;

    table = (hash_t *)malloc(sizeof(hash_t));
	if(!pthread_mutex_init(&(table->mutex), NULL) < 0)
	{
		xLog(XLOG_WARNING, "%s[%d]: mutex_init failed", __func__, __LINE__);
		free(table);
		table = NULL;
	}
	else
	{
		htable_size(table, size < 13 ? 13 : size);
		table->seq_element = 0;
	}
	

	return (table);
}

static void htable_grow(hash_t *table)
{
    hash_info_t *ht;
    hash_info_t *next;
    unsigned old_size = table->size;
    hash_info_t **h = table->data;
    hash_info_t **old_entries = h;

    htable_size(table, 2 * old_size);

    while (old_size-- > 0) {
		for (ht = *h++; ht; ht = next) {
			next = ht->next;
			htable_link(table, ht);
		}
    }
    free((char *)old_entries);
}

hash_info_t *hash_insert(hash_t *table, const char *key, void *value)
{
//	xLog(XLOG_DEBUG, "%s[%d]: insert key[%s], value[%s]", __func__, __LINE__, key, value);
	hash_info_t *ht = NULL;
	if(!pthread_mutex_lock(&(table->mutex)))
	{
		if (table->used >= table->size && table->seq_element == 0)
			htable_grow(table);
		ht = (hash_info_t *)malloc(sizeof(hash_info_t));
		ht->key = strdup(key);
		ht->value = value;
		htable_link(table, ht);
		pthread_mutex_unlock(&(table->mutex));
	}
    return (ht);
}

void hash_delete(hash_t *table, const char *key, void (*free_fn) (void *))
{
	if (table) {
		if(!pthread_mutex_lock(&(table->mutex))){
			hash_info_t *ht;
			hash_info_t **h = table->data + htable_hash(key, table->size);

	#define	STREQ(x,y) (x == y || (x[0] == y[0] && strcmp(x,y) == 0))

			for (ht = *h; ht; ht = ht->next) {
				if (STREQ(key, ht->key)) {
					if (ht->next)
						ht->next->prev = ht->prev;
					if (ht->prev)
						ht->prev->next = ht->next;
					else
						*h = ht->next;
					table->used--;
					free(ht->key);
					if (free_fn && ht->value)
						(*free_fn)((char *)ht->value);
					free((char *) ht);
					//return;
				}
			}
			pthread_mutex_unlock(&(table->mutex));
		}
		//xLog(XLOG_WARNING, "hash_delete: unknown_key: \"%s\"", key);
    }
}

void *hash_find(hash_t *table, const char *key)
{
    hash_info_t *ht;

#define	STREQ(x,y) (x == y || (x[0] == y[0] && strcmp(x,y) == 0))

    if (table)
	{
		if(!pthread_mutex_lock(&(table->mutex)))
		{
			for (ht = table->data[htable_hash(key, table->size)]; ht; ht = ht->next)
			{
				if (STREQ(key, ht->key))
				{
					pthread_mutex_unlock(&(table->mutex));
					return (ht->value);
				}
			}
			pthread_mutex_unlock(&(table->mutex));
		}
	}
    return (NULL);
}

void hash_destroy(hash_t *table, void (*free_fn)(void *))
{
	if (table) {
		if(!pthread_mutex_lock(&(table->mutex)))
		{
			unsigned i = table->size;
			hash_info_t *ht;
			hash_info_t *next;
			hash_info_t **h = table->data;

			while (i-- > 0) {
				for (ht = *h++; ht; ht = next) {
					next = ht->next;
					free(ht->key);
					if (free_fn && ht->value)
						(*free_fn)((char *)ht->value);
					free((char *) ht);
				}
			}
			free((char *) table->data);
			table->data = 0;
			pthread_mutex_unlock(&(table->mutex));
			pthread_mutex_destroy(&(table->mutex));
			free((char *) table);		
		}
    }
}
