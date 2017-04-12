
#ifndef _MERGE_FILE_H
#define _MERGE_FILE_H

#include "def.h"
#include "config.h"
#include "merge_file_thread.h"

int merge_file(char *dir_path);
int cut_file_name(char *src_name, char *prefix, merge_file_list_elm_t *elm);
int do_unusual_file(char *src_dir, char *des_dir);
int backup_info_read(char *file_name, uint32 *file_order, uint32 *offset);

#endif

