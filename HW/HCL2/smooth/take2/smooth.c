#include <stdio.h>
#include <stdlib.h>
#include "defs.h"
#include <smmintrin.h>
#include <immintrin.h>

/* 
 * Please fill in the following team struct 
 */
who_t who = {
    "Prof Ryals",           /* Scoreboard name */

    "Nathan Hartung",      /* First member full name */
    "nrh9bef@virginia.edu",     /* First member email address */
};

/*** UTILITY FUNCTIONS ***/

/* You are free to use these utility functions, or write your own versions
 * of them. */

/* A struct used to compute averaged pixel value */
typedef struct {
    unsigned short red;
    unsigned short green;
    unsigned short blue;
    unsigned short alpha;
    unsigned short num;
} pixel_sum;

/* Compute min and max of two integers, respectively */
static int min(int a, int b) { return (a < b ? a : b); }
static int max(int a, int b) { return (a > b ? a : b); }

/* 
 * initialize_pixel_sum - Initializes all fields of sum to 0 
 */
static void initialize_pixel_sum(pixel_sum *sum) 
{
    sum->red = sum->green = sum->blue = sum->alpha = 0;
    sum->num = 0;
    return;
}

/* 
 * accumulate_sum - Accumulates field values of p in corresponding 
 * fields of sum 
 */
static void accumulate_sum(pixel_sum *sum, pixel p) 
{
    sum->red += (int) p.red;
    sum->green += (int) p.green;
    sum->blue += (int) p.blue;
    sum->alpha += (int) p.alpha;
    sum->num++;
    return;
}

/* 
 * assign_sum_to_pixel - Computes averaged pixel value in current_pixel 
 */
static void assign_sum_to_pixel(pixel *current_pixel, pixel_sum sum) 
{
    current_pixel->red = (unsigned short) (sum.red/sum.num);
    current_pixel->green = (unsigned short) (sum.green/sum.num);
    current_pixel->blue = (unsigned short) (sum.blue/sum.num);
    current_pixel->alpha = (unsigned short) (sum.alpha/sum.num);
    return;
}

/* 
 * avg - Returns averaged pixel value at (i,j) 
 */
static pixel avg(int dim, int i, int j, pixel *src) 
{
    pixel_sum sum;
    pixel current_pixel;

    initialize_pixel_sum(&sum);
    for(int jj=max(j-1, 0); jj <= min(j+1, dim-1); jj++) 
	for(int ii=max(i-1, 0); ii <= min(i+1, dim-1); ii++) 
	    accumulate_sum(&sum, src[RIDX(ii,jj,dim)]);

    assign_sum_to_pixel(&current_pixel, sum);
 
    return current_pixel;
}



/******************************************************
 * Your different versions of the smooth go here
 ******************************************************/

/* 
 * naive_smooth - The naive baseline version of smooth
 */
char naive_smooth_descr[] = "naive_smooth: Naive baseline implementation";
void naive_smooth(int dim, pixel *src, pixel *dst) 
{
    for (int i = 0; i < dim; i++)
	for (int j = 0; j < dim; j++)
            dst[RIDX(i,j, dim)] = avg(dim, i, j, src);
}
/* 
 * smooth - Your current working version of smooth
 *          Our supplied version simply calls naive_smooth
 */
char another_smooth_descr[] = "another_smooth: Another version of smooth";
void another_smooth(int dim, pixel *src, pixel *dst) 
{
  // Corner pixels
  dst[RIDX(0, 0, dim)] = avg(dim, 0, 0, src);
  dst[RIDX(dim-1, 0, dim)] = avg(dim, dim-1, 0, src);
  dst[RIDX(0, dim-1, dim)] = avg(dim, 0, dim-1, src);
  dst[RIDX(dim-1, dim-1, dim)] = avg(dim, dim-1, dim-1, src);
  // Edge pixels

  // Top edge
  for (int i = 1; i < dim-1; i++)
      dst[RIDX(i, 0, dim)] = avg(dim, i, 0, src);

  // Bottom edge
  for (int i = 1; i < dim-1; i++)
      dst[RIDX(i, dim-1, dim)] = avg(dim, i, dim-1, src);

  // Left edge
  for (int j = 1; j < dim-1; j++)
      dst[RIDX(0, j, dim)] = avg(dim, 0, j, src);

  // Right edge
  for (int j = 1; j < dim-1; j++)
      dst[RIDX(dim-1, j, dim)] = avg(dim, dim-1, j, src);

  // Middle pixels
    for (int i = 1; i < dim-1; i++)
      for (int j = 1; j < dim-1; j++) {
	pixel_sum sum;
	pixel current_pixel;

	initialize_pixel_sum(&sum);
	accumulate_sum(&sum, src[RIDX(i-1,j-1,dim)]);
	accumulate_sum(&sum, src[RIDX(i,j-1,dim)]);
	accumulate_sum(&sum, src[RIDX(i+1,j-1,dim)]);
	accumulate_sum(&sum, src[RIDX(i-1,j,dim)]);
	accumulate_sum(&sum, src[RIDX(i,j,dim)]);
	accumulate_sum(&sum, src[RIDX(i+1,j,dim)]);
	accumulate_sum(&sum, src[RIDX(i-1,j+1,dim)]);
	accumulate_sum(&sum, src[RIDX(i,j+1,dim)]);
	accumulate_sum(&sum, src[RIDX(i+1,j+1,dim)]);
		
	current_pixel.red = (unsigned short) (sum.red/9);
	current_pixel.green = (unsigned short) (sum.green/9);
	current_pixel.blue = (unsigned short) (sum.blue/9);
	current_pixel.alpha = (unsigned short) (sum.alpha/9);

	dst[RIDX(i,j, dim)] = current_pixel;
      }
}

char smooth_AVX_descr[] = "smooth_AVX: smooth with vector instructions";
void smooth_AVX(int dim, pixel *src, pixel *dst) {
  // Corner pixels
  dst[RIDX(0, 0, dim)] = avg(dim, 0, 0, src);
  dst[RIDX(dim-1, 0, dim)] = avg(dim, dim-1, 0, src);
  dst[RIDX(0, dim-1, dim)] = avg(dim, 0, dim-1, src);
  dst[RIDX(dim-1, dim-1, dim)] = avg(dim, dim-1, dim-1, src);
  // Edge pixels

  // Top edge
  for (int i = 1; i < dim-1; i++)
      dst[RIDX(i, 0, dim)] = avg(dim, i, 0, src);

  // Bottom edge
  for (int i = 1; i < dim-1; i++)
      dst[RIDX(i, dim-1, dim)] = avg(dim, i, dim-1, src);

  // Left edge
  for (int j = 1; j < dim-1; j++)
      dst[RIDX(0, j, dim)] = avg(dim, 0, j, src);

  // Right edge
  for (int j = 1; j < dim-1; j++)
      dst[RIDX(dim-1, j, dim)] = avg(dim, dim-1, j, src);

  // Middle pixels
  for (int i = 1; i < dim-1; i++) {
    for (int j = 1; j < dim-1; j++) {
      pixel current_pixel;

      // load 128 bits (4 pixels) and convert into 16 bit values
      __m128i pixel1_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i-1, j-1, dim)]);
      __m256i pixel1_16bit = _mm256_cvtepu8_epi16(pixel1_8bit);
      __m128i pixel2_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i, j-1, dim)]);
      __m256i pixel2_16bit = _mm256_cvtepu8_epi16(pixel2_8bit);
      __m128i pixel3_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i+1, j-1, dim)]);
      __m256i pixel3_16bit = _mm256_cvtepu8_epi16(pixel3_8bit);
      __m128i pixel4_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i-1, j, dim)]);
      __m256i pixel4_16bit = _mm256_cvtepu8_epi16(pixel4_8bit);
      __m128i pixel5_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i, j, dim)]);
      __m256i pixel5_16bit = _mm256_cvtepu8_epi16(pixel5_8bit);
      __m128i pixel6_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i+1, j, dim)]);
      __m256i pixel6_16bit = _mm256_cvtepu8_epi16(pixel6_8bit);
      __m128i pixel7_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i-1, j+1, dim)]);
      __m256i pixel7_16bit = _mm256_cvtepu8_epi16(pixel7_8bit);
      __m128i pixel8_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i, j+1, dim)]);
      __m256i pixel8_16bit = _mm256_cvtepu8_epi16(pixel8_8bit);
      __m128i pixel9_8bit = _mm_loadu_si128((__m128i*) &src[RIDX(i+1, j+1, dim)]);
      __m256i pixel9_16bit = _mm256_cvtepu8_epi16(pixel9_8bit);

      // add pixel components
      __m256i sum_of_pixels = _mm256_setzero_si256();
      sum_of_pixels += _mm256_add_epi16(pixel1_16bit, pixel2_16bit);
      sum_of_pixels += _mm256_add_epi16(pixel3_16bit, pixel4_16bit);
      sum_of_pixels += _mm256_add_epi16(pixel5_16bit, pixel6_16bit);
      sum_of_pixels += _mm256_add_epi16(pixel7_16bit, pixel8_16bit);
      sum_of_pixels = _mm256_add_epi16(pixel9_16bit, sum_of_pixels);

      // find average values for each pixel component

      // perform pixel_element / 9 by doing (pixel_element * 7282) >> 16
      //__m128i value_16bit = _mm_set1_epi16(7282);
      //__m256i value_16bit = _mm256_cvtepu8_epi16(value_8bit);
      //__m256i pixel_product = _mm256_mulhi_epi16(sum_of_pixels, value_16bit);
      //pixel_product = _mm256_srli_epi16(pixel_product, 16);

      // put pixel elements in an array to extract and store
      unsigned short pixel_elements[16];

      _mm256_storeu_si256((__m256i*) pixel_elements, sum_of_pixels);

      // _mm256_storeu_si256((__m256i*) pixel_elements, pixel_product);
      //current_pixel.red = pixel_elements[0];
      //current_pixel.green = pixel_elements[1];
      //current_pixel.blue = pixel_elements[2];
      //current_pixel.alpha = pixel_elements[3];

      current_pixel.red = pixel_elements[0] / 9;
      current_pixel.green = pixel_elements[1] / 9;
      current_pixel.blue = pixel_elements[2] / 9;
      current_pixel.alpha = pixel_elements[3] / 9;

      dst[RIDX(i,j, dim)] = current_pixel;
    }
  }
}

/*********************************************************************
 * register_smooth_functions - Register all of your different versions
 *     of the smooth function by calling the add_smooth_function() for
 *     each test function. When you run the benchmark program, it will
 *     test and report the performance of each registered test
 *     function.  
 *********************************************************************/

void register_smooth_functions() {
    add_smooth_function(&naive_smooth, naive_smooth_descr);
    add_smooth_function(&another_smooth, another_smooth_descr);
    add_smooth_function(&smooth_AVX, smooth_AVX_descr);
}
