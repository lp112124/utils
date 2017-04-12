#ifndef __HASH_H
#define __HASH_H

#include "def.h"

typedef struct hash_info_s hash_info_t;
struct hash_info_s{
    char   *key;			/* lookup key */
    void   *value;			/* associated value */
    struct hash_info_s *next;		/* colliding entry */
    struct hash_info_s *prev;		/* colliding entry */
} ;

 /* Structure of one hash table. */
typedef struct hash_s hash_t;
struct hash_s{
    int     size;			/* length of entries array */
    int     used;			/* number of entries in table */
    hash_info_t **data;			/* entries array, auto-resized */
    hash_info_t **seq_bucket;		/* current sequence hash bucket */
    hash_info_t *seq_element;		/* current sequence element */
	pthread_mutex_t mutex;			/* added for thread support */
};

extern hash_t *hash_create(int);
extern hash_info_t *hash_insert(hash_t *, const char *, void *);
extern void hash_delete(hash_t *, const char *, void (*free_fn) (void *));
extern void *hash_find(hash_t *, const char *);
extern void hash_destroy(hash_t *, void (*free_fn)(void *));

#endif
