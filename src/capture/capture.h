#ifndef __CAPTURE_H
#define __CAPTURE_H

#include <netinet/in.h>
#include <stdint.h>
#include <inttypes.h>
#include "dada_hdu.h"
#include "dada_def.h"
#include "ipcio.h"
#include "ascii_header.h"
#include "daemon.h"
#include "futils.h"

#define MSTR_LEN      1024
#define MPORT_CAPTURE 16
#define DADA_HDRSZ    4096
#define MCHK_CAPTURE  48
#define SECDAY        86400.0
#define MJD1970       40587.0

typedef struct ref_t
{  
  uint64_t sec, idf; // Reference seconds and idf, from BMF when we start the capture 
  int epoch;
  time_t sec_int;
  uint64_t picoseconds;
}ref_t;
  
typedef struct conf_t
{
  ref_t ref;
  key_t key;
  dada_hdu_t *hdu;
  
  uint64_t rbuf_ndf_chk, tbuf_ndf_chk;

  int pad;
  int pktsz, pktoff, required_pktsz;
  int cpt_cpu[MPORT_CAPTURE];
  int rbuf_ctrl_cpu, cpt_ctrl_cpu;
  int cpt_ctrl;
  char cpt_ctrl_addr[MSTR_LEN];
  int cpu_bind;
  
  char ip_alive[MPORT_CAPTURE][MSTR_LEN];
  int port_alive[MPORT_CAPTURE];
  int nport_alive;
  int nchk_alive_expect[MPORT_CAPTURE];  // For each port;
  int nchk_alive_actual[MPORT_CAPTURE];  // For each port;

  char ip_dead[MPORT_CAPTURE][MSTR_LEN];
  int port_dead[MPORT_CAPTURE];
  int nport_dead;
  int nchk_dead[MPORT_CAPTURE];

  char instrument[MSTR_LEN];
  double cfreq;
  int nchan, nchan_chk, nchk, nchk_alive;    // Frequency chunks of current capture, including all alive chunks and dead chunks
  
  char hfname[MSTR_LEN];

  int prd;
  char dir[MSTR_LEN];
  double df_res;  // time resolution of each data frame, for start time determination;
  double blk_res; // time resolution of each buffer block, for start time determination;

  //int ichk0;
  double ichk0;
  uint64_t rbufsz, tbufsz;

  char source[MSTR_LEN], ra[MSTR_LEN], dec[MSTR_LEN];
  
  double chan_res, bw;
  time_t sec_int;
  uint64_t picoseconds;
  char utc_start[MSTR_LEN];
  double mjd_start;

  struct timeval tout;
  uint64_t ndf_chk_prd;
}conf_t;

typedef struct hdr_t
{
  int      valid;   // 0 the data frame is not valied, 1 the data frame is valied;
  uint64_t idf;     // data frame number in one period;
  uint64_t sec;     // Secs from reference epochch at start of period;
  int      epoch;   // Number of half a year from 1st of January, 2000 for the reference epochch;
  int      beam;    // The id of beam, counting from 0;
  double   freq;    // Frequency of the first chunnal in each block (integer MHz);
}hdr_t;

int init_capture(conf_t *conf);
void *capture(void *conf);
int acquire_idf(uint64_t idf, uint64_t sec, uint64_t idf_ref, uint64_t sec_ref, double df_res, int64_t *idf_buf);
int acquire_ichk(double freq, int nchan_chk, double ichk0, int nchk, int *ichk);
int init_buf(conf_t *conf);
int destroy_capture(conf_t conf);

void *capture_control(void *conf);

int threads(conf_t *conf);
void *buf_control(void *conf);

int hdr_keys(char *df, hdr_t *hdr);
uint64_t hdr_idf(char *df);
uint64_t hdr_sec(char *df);
double hdr_freq(char *df);
int init_hdr(hdr_t *hdr);
int dada_header(conf_t conf);

#endif
