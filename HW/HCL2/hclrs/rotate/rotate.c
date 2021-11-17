#include <stdio.h>
#include <stdlib.h>
#include "defs.h"

/* 
 * Please fill in the following struct with your name and the name you'd like to appear on the scoreboard
 */
who_t who = {
    "Prof Ryals",           /* Scoreboard name */

    "Nathan Hartung",   /* Full name */
    "nrh9bef@virginia.edu",  /* Email address */
};

/***************
 * ROTATE KERNEL
 ***************/

/******************************************************
 * Your different versions of the rotate kernel go here
 ******************************************************/
char cache_block_16_descr[] = "cache_block_16: cache blocking in multiples of 16";
void cache_block_16(int dim, pixel *src, pixel *dst) 
{
for (int ii = 0; ii < dim; ii += 16)
  for (int jj = 0; jj < dim; jj += 16)
    for (int i = ii; i < ii + 16; ++i)
      for (int j = jj; j < jj + 16; ++j)
	  dst[RIDX(dim-1-j, i, dim)] = src[RIDX(i, j, dim)];
}

char cache_block_32_descr[] = "cache_block_32: cache blocking in multiples of 32";
void cache_block_32(int dim, pixel *src, pixel *dst) 
{
for (int ii = 0; ii < dim; ii += 32)
  for (int jj = 0; jj < dim; jj += 32)
    for (int i = ii; i < ii + 32; ++i)
      for (int j = jj; j < jj + 32; ++j)
	dst[RIDX(dim-1-j, i, dim)] = src[RIDX(i, j, dim)];
}

/* 
 * naive_rotate - The naive baseline version of rotate 
 */
char naive_rotate_descr[] = "naive_rotate: Naive baseline implementation";
void naive_rotate(int dim, pixel *src, pixel *dst) 
{
    for (int i = 0; i < dim; i++)
	for (int j = 0; j < dim; j++)
	    dst[RIDX(dim-1-j, i, dim)] = src[RIDX(i, j, dim)];
}
/* 
 * rotate - Your current working version of rotate
 *          Our supplied version simply calls naive_rotate
 */

char loop_unrolling_descr[] = "naive_rotate: Naive baseline implementation";
void loop_unrolling(int dim, pixel *src, pixel *dst) 
{
    for (int i = 0; i < dim; i+=4)
      for (int j = 0; j < dim; j+=4) {
       	    dst[RIDX(dim-1-j, i, dim)] = src[RIDX(i, j, dim)];
	    dst[RIDX(dim-1-(j+1), i+1, dim)] = src[RIDX(i+1, j+1, dim)];
	    dst[RIDX(dim-1-(j+2), i+2, dim)] = src[RIDX(i+2, j+2, dim)];
	    dst[RIDX(dim-1-(j+3), i+3, dim)] = src[RIDX(i+3, j+3, dim)];
	}
}

/*********************************************************************
 * register_rotate_functions - Register all of your different versions
 *     of the rotate function by calling the add_rotate_function() for
 *     each test function. When you run the benchmark program, it will
 *     test and report the performance of each registered test
 *     function.  
 *********************************************************************/

void register_rotate_functions() {
    add_rotate_function(&naive_rotate, naive_rotate_descr);
    add_rotate_function(&cache_block_16, cache_block_16_descr);
    add_rotate_function(&cache_block_32, cache_block_32_descr);
    add_rotate_function(&loop_unrolling, loop_unrolling_descr);
}
