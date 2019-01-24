#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <cuda_runtime.h>
#include <cuda.h>
#include <cufft.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <inttypes.h>
#include "cudautil.cuh"
#include "kernel.cuh"

#define MAX_RAND   1000
#define NBYTE_RT   4

extern "C" void usage ()
{
  fprintf (stdout,
	   "reduce6_test - Test the reduce6 kernel \n"
	   "\n"
	   "Usage: reduce6_test [options]\n"
	   " -a  Grid size in X\n"
	   " -b  Grid size in Y\n"
	   " -c  Block size in X\n"
	   " -d  Number of samples to accumulate in each block\n"
	   " -h  show help\n");
}

// ./reduce6_test -a 512 -b 1 -c 512 -d 1024
int main(int argc, char *argv[])
{
  int i, j, arg;
  int grid_x, grid_y, block_x, n_accumulate;
  uint64_t len_in, len_out, idx;
  dim3 gridsize_reduce6, blocksize_reduce6;
  cufftComplex *h_result = NULL, *g_result = NULL, *data = NULL, *g_in = NULL, *g_out = NULL;
  
  /* Read in parameters, the arguments here have the same name  */
  while((arg=getopt(argc,argv,"a:b:hc:d:")) != -1)
    {
      switch(arg)
	{
	case 'h':
	  usage();
	  exit(EXIT_FAILURE);	  

	case 'a':	  
	  if (sscanf (optarg, "%d", &grid_x) != 1)
	    {
	      fprintf (stderr, "Does not get grid_x, which happens at \"%s\", line [%d].\n", __FILE__, __LINE__);
	      exit(EXIT_FAILURE);
	    }
	  break;
	  
	case 'b':	  
	  if (sscanf (optarg, "%d", &grid_y) != 1)
	    {
	      fprintf (stderr, "Does not get grid_y, which happens at \"%s\", line [%d].\n", __FILE__, __LINE__);
	      exit(EXIT_FAILURE);
	    }
	  break;
	  
	case 'c':	  
	  if (sscanf (optarg, "%d", &block_x) != 1)
	    {
	      fprintf (stderr, "Does not get block_x, which happens at \"%s\", line [%d].\n", __FILE__, __LINE__);
	      exit(EXIT_FAILURE);
	    }
	  
	case 'd':	  
	  if (sscanf (optarg, "%d", &n_accumulate) != 1)
	    {
	      fprintf (stderr, "Does not get n_accumulate, which happens at \"%s\", line [%d].\n", __FILE__, __LINE__);
	      exit(EXIT_FAILURE);
	    }
	  fprintf(stdout, "n_accumulate is %d\n",  n_accumulate);
	  break;
	}
    }

  fprintf(stdout, "grid_x is %d, grid_y is %d, block_x is %d and n_accumulate is %d\n", grid_x, grid_y, block_x, n_accumulate);
  
  /* Setup size */
  gridsize_reduce6.x  = grid_x;
  gridsize_reduce6.y  = grid_y;
  gridsize_reduce6.z  = 1;
  blocksize_reduce6.x = block_x;
  blocksize_reduce6.y = 1;
  blocksize_reduce6.z = 1;
  len_out             = grid_x*grid_y;
  len_in              = len_out*n_accumulate;

  /* Create buffer */
  CudaSafeCall(cudaMallocHost((void **)&data,     len_in * sizeof(cufftComplex)));
  CudaSafeCall(cudaMallocHost((void **)&h_result, len_out * sizeof(cufftComplex)));
  CudaSafeCall(cudaMallocHost((void **)&g_result, len_out * sizeof(cufftComplex)));
  CudaSafeCall(cudaMalloc((void **)&g_in,         len_in * sizeof(cufftComplex)));
  CudaSafeCall(cudaMalloc((void **)&g_out,        len_out * sizeof(cufftComplex)));

  /* cauculate on CPU */
  srand(time(NULL));
  for(i = 0; i < len_out; i ++)
    {
      h_result[i].x = 0;
      h_result[i].y = 0;
      for(j = 0; j < n_accumulate; j++)
	{
	  idx = i * len_out + j;
	  data[idx].x = (float)rand()/(float)(RAND_MAX/(float)MAX_RAND);
	  data[idx].y = (float)rand()/(float)(RAND_MAX/(float)MAX_RAND);

	  h_result[i].x += data[idx].x;
	  h_result[i].y += data[idx].y;
	}
    }

  /* Calculate on GPU */
  CudaSafeCall(cudaMemcpy(g_in, data, len_in * sizeof(cufftComplex), cudaMemcpyHostToDevice));
  switch (blocksize_reduce6.x)
    {
    case 1024:
      fprintf(stdout, "1024\n");
      fflush(stdout);
      reduce6_kernel<1024><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 512:
      fprintf(stdout, "512\n");
      fflush(stdout);
      reduce6_kernel< 512><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 256:
      fprintf(stdout, "256\n");
      fflush(stdout);
      reduce6_kernel< 256><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 128:
      fprintf(stdout, "128\n");
      fflush(stdout);
      reduce6_kernel< 128><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 64:
      fprintf(stdout, "64\n");
      fflush(stdout);
      reduce6_kernel<  64><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 32:
      fprintf(stdout, "32\n");
      fflush(stdout);
      reduce6_kernel<  32><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 16:
      fprintf(stdout, "16\n");
      fflush(stdout);
      reduce6_kernel<  16><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 8:
      fprintf(stdout, "8\n");
      fflush(stdout);
      reduce6_kernel<   8><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 4:
      fprintf(stdout, "4\n");
      fflush(stdout);
      reduce6_kernel<   4><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 2:
      fprintf(stdout, "2\n");
      fflush(stdout);
      reduce6_kernel<   2><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
      
    case 1:
      fprintf(stdout, "1\n");
      fflush(stdout);
      reduce6_kernel<   1><<<gridsize_reduce6, blocksize_reduce6, blocksize_reduce6.x * NBYTE_RT>>>(g_in, g_out, n_accumulate);
      break;
    }
  CHECK_LAUNCH_ERROR();
  CudaSafeCall(cudaMemcpy(h_result, g_out, len_out * sizeof(cufftComplex), cudaMemcpyDeviceToHost));
  
  /* Free buffer */
  CudaSafeCall(cudaFreeHost(data));
  CudaSafeCall(cudaFreeHost(h_result));
  CudaSafeCall(cudaFreeHost(g_result));
  CudaSafeCall(cudaFree(g_in));
  CudaSafeCall(cudaFree(g_out));
  
  return EXIT_SUCCESS;
}