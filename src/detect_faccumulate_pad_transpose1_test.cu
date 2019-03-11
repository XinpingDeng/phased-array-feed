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

#include "constants.h"

#define NBYTE   4

extern "C" void usage ()
{
  fprintf (stdout,
	   "detect_faccumulate_pad_transpose1_test - Test the detect_faccumulate_pad_transpose1 kernel \n"
	   "\n"
	   "Usage: detect_faccumulate_pad_transpose1_test [options]\n"
	   " -a  Grid size in X, which is number of samples in time\n"
	   " -b  Grid size in Y, which is number of channels\n"
	   " -c  Block size in X\n"
	   " -d  Number of samples to accumulate in each block\n"
	   " -h  show help\n");
}

// ./detect_faccumulate_pad_transpose1_test -a 512 -b 1 -c 512 -d 1024 
int main(int argc, char *argv[])
{
  int i, j,l, k, arg;
  int grid_x, grid_y, block_x;
  uint64_t n_accumulate, idx;
  uint64_t nsamp, npol, nout;
  dim3 gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1;
  cufftComplex *g_in = NULL, *data = NULL, *g_out = NULL, *g_result = NULL, *h_result = NULL;
  float accumulate;
  
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
	  break;
	  
	case 'd':	  
	  if (sscanf (optarg, "%"SCNu64"", &n_accumulate) != 1)
	    {
	      fprintf (stderr, "Does not get n_accumulate, which happens at \"%s\", line [%d].\n", __FILE__, __LINE__);
	      exit(EXIT_FAILURE);
	    }
	  fprintf(stdout, "n_accumulate is %"PRIu64"\n",  n_accumulate);
	  break;
	}
    }

  fprintf(stdout, "grid_x is %d, grid_y is %d, block_x is %d and n_accumulate is %"SCNu64"\n", grid_x, grid_y, block_x, n_accumulate);
  
  /* Setup size */
  gridsize_detect_faccumulate_pad_transpose1.x  = grid_x;
  gridsize_detect_faccumulate_pad_transpose1.y  = grid_y;
  gridsize_detect_faccumulate_pad_transpose1.z  = 1;
  blocksize_detect_faccumulate_pad_transpose1.x = block_x;
  blocksize_detect_faccumulate_pad_transpose1.y = 1;
  blocksize_detect_faccumulate_pad_transpose1.z = 1;
  nout                                 = grid_x*grid_y;
  nsamp                                = nout*n_accumulate;
  npol                                 = NPOL_BASEBAND * nsamp;
   
  /* Create buffer */
  CudaSafeCall(cudaMallocHost((void **)&data, npol * NBYTE_CUFFT_COMPLEX));
  CudaSafeCall(cudaMallocHost((void **)&h_result, nout * NBYTE_CUFFT_COMPLEX));
  CudaSafeCall(cudaMallocHost((void **)&g_result, nout * NBYTE_CUFFT_COMPLEX));
  CudaSafeCall(cudaMalloc((void **)&g_out, nout * NBYTE_CUFFT_COMPLEX));
  CudaSafeCall(cudaMalloc((void **)&g_in, npol * NBYTE_CUFFT_COMPLEX));
  CudaSafeCall(cudaMemset((void *)h_result, 0, sizeof(h_result)));
  
  /* cauculate on CPU */
  srand(time(NULL));
  for(i = 0; i < grid_x; i ++) // Prepare the input data
    {
      for(j = 0; j < grid_y; j ++)
	{
	  accumulate = 0;
	  for(k = 0; k < n_accumulate; k++)
	    {
	      idx = (i*grid_y + j) * n_accumulate + k;
	      for(l = 0; l < NPOL_BASEBAND; l++)
		{
		  data[idx+l*nsamp].x = fabs(rand()*RAND_STD/RAND_MAX)/100.;
		  data[idx+l*nsamp].y = fabs(rand()*RAND_STD/RAND_MAX)/100.;
		  accumulate += (data[idx+l*nsamp].x*data[idx+l*nsamp].x + data[idx+l*nsamp].y*data[idx+l*nsamp].y);
		}
 	    }
	  h_result[j*grid_x+i].x += accumulate; 
	  h_result[j*grid_x+i].y += (accumulate*accumulate);
	}
    }
    
  /* Calculate on GPU */
  CudaSafeCall(cudaMemcpy(g_in, data, npol * NBYTE_CUFFT_COMPLEX, cudaMemcpyHostToDevice));
    
  switch (blocksize_detect_faccumulate_pad_transpose1.x)
    {
    case 1024:
      detect_faccumulate_pad_transpose1_kernel<1024><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 512:
      detect_faccumulate_pad_transpose1_kernel< 512><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 256:
      detect_faccumulate_pad_transpose1_kernel< 256><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 128:
      detect_faccumulate_pad_transpose1_kernel< 128><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 64:
      detect_faccumulate_pad_transpose1_kernel<  64><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 32:
      detect_faccumulate_pad_transpose1_kernel<  32><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 16:
      detect_faccumulate_pad_transpose1_kernel<  16><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 8:
      detect_faccumulate_pad_transpose1_kernel<   8><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 4:
      detect_faccumulate_pad_transpose1_kernel<   4><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 2:
      detect_faccumulate_pad_transpose1_kernel<   2><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
      
    case 1:
      detect_faccumulate_pad_transpose1_kernel<   1><<<gridsize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1, blocksize_detect_faccumulate_pad_transpose1.x * NBYTE>>>(g_in, g_out, nsamp, n_accumulate);
      break;
    }
  CudaSafeKernelLaunch();

  CudaSafeCall(cudaMemcpy(g_result, g_out, nout * NBYTE_CUFFT_COMPLEX, cudaMemcpyDeviceToHost));
 
  /* Check the result */
  for(i = 0; i < nout; i++)
    fprintf(stdout, "CPU:\t%f\t%f\tGPU:\t%f\t%f\tDifference\t%E\t%E\n", h_result[i].x, h_result[i].y, g_result[i].x, g_result[i].y, (g_result[i].x - h_result[i].x)/h_result[i].x, (g_result[i].y - h_result[i].y)/h_result[i].y);
  
  /* Free buffer */  
  CudaSafeCall(cudaFreeHost(h_result));
  CudaSafeCall(cudaFreeHost(g_result));
  CudaSafeCall(cudaFreeHost(data));
  CudaSafeCall(cudaFree(g_out));
  CudaSafeCall(cudaFree(g_in));
  
  return EXIT_SUCCESS;
}