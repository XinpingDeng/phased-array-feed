#!/usr/bin/env python

import ConfigParser, parser, argparse, socket, struct, json, os, subprocess, threading, datetime, time
import numpy as np

SECDAY      = 86400.0
DADA_TIMSTR = "%Y-%m-%d-%H:%M:%S"
MJD1970     = 40587.0

def ConfigSectionMap(fname, section):
    # Play with configuration file
    Config = ConfigParser.ConfigParser()
    Config.read(fname)
    
    dict_conf = {}
    options = Config.options(section)
    for option in options:
        try:
            dict_conf[option] = Config.get(section, option)
            if dict_conf[option] == -1:
                DebugPrint("skip: %s" % option)
        except:
            print("exception on %s!" % option)
            dict_conf[option] = None
    return dict_conf

def capture_reftime(destination, pktsz, df_res, system_conf):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_address = (destination.split("_")[0], int(destination.split("_")[1]))
    sock.bind(server_address)
    buf, address = sock.recvfrom(pktsz) # raw packet
    
    data       = np.fromstring(buf, 'uint64')
    hdr_part   = np.uint64(struct.unpack("<Q", struct.pack(">Q", data[0]))[0])
    df_sec     = (hdr_part & np.uint64(0x3fffffff00000000)) >> np.uint64(32)
    df_idf     = hdr_part & np.uint64(0x00000000ffffffff)

    hdr_part   = np.uint64(struct.unpack("<Q", struct.pack(">Q", data[1]))[0])
    epoch      = (hdr_part & np.uint64(0x00000000fc000000)) >> np.uint64(26)
    epoch      = float(ConfigSectionMap(system_conf, "EpochBMF")['{:d}'.format(epoch)])

    sec_prd    = df_idf * df_res
    sec_epoch  = df_sec + np.floor(sec_prd) + epoch * SECDAY  # Int part of seconds from 1970-01-01

    utc_start  = time.strftime(DADA_TIMSTR, time.gmtime(sec_epoch))    # UTC_START of int part seconds
    mjd_start  = sec_epoch/SECDAY + MJD1970                            # MJD_START of int part seconds
    
    microseconds = 1.0E6 * (sec_prd - np.floor(sec_prd))
    picoseconds  = int(1E6 * round(microseconds))                # picoseconds of fraction second
        
    return int(df_sec), df_idf, utc_start, mjd_start, picoseconds
    
def check_all_ports(destination, pktsz, df_prd, ndf_check):
    nport = len(destination)
    active = np.zeros(nport, dtype = int)
    nchunk_active = np.zeros(nport, dtype = int)
    socket.setdefaulttimeout(df_prd)  # Force to timeout after one data frame period
    
    for i in range(nport):
        active[i], nchunk_active[i] = check_port(destination[i].split(":")[0], int(destination[i].split(":")[1]), pktsz, ndf_check)
    destination_active = []   # The destination where we can receive data
    destination_dead   = []   # The destination where we can not receive data
    for i in range(nport):
        if active[i] == 1:
            destination_active.append("{:s}_{:s}_{:s}_{:d}".format(destination[i].split(":")[0], destination[i].split(":")[1], destination[i].split(":")[2], nchunk_active[i]))
        else:
            destination_dead.append("{:s}_{:s}_{:s}".format(destination[i].split(":")[0], destination[i].split(":")[1], destination[i].split(":")[2]))
    return destination_active, destination_dead
    
def check_port(ip, port, pktsz, ndf_check):
    active = 1
    nchunk_active = 0
    data = bytearray(pktsz) 
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_address = (ip, port)
    sock.bind(server_address)
    
    try:
        nbyte, address = sock.recvfrom_into(data, pktsz)
        if (nbyte != pktsz):
            active = 0
        else:
            source = []
            active = 1
            for i in range(ndf_check):
                buf, address = sock.recvfrom(pktsz)
                source.append(address)
            nchunk_active = len(set(source))
    except:
        active = 0        

    return active, nchunk_active

def captureinfo(pipeline_conf, system_conf, destination, nchan, hdr, beam, part):
    # Get pipeline configuration from configuration file
    ndf_blk      = int(ConfigSectionMap(pipeline_conf, "CAPTURE")['ndf_blk'])
    ndf_check    = int(ConfigSectionMap(pipeline_conf, "CAPTURE")['ndf_check'])
    nblk         = int(ConfigSectionMap(pipeline_conf, "CAPTURE")['nblk'])
    key          = format(int("0x{:s}".format(ConfigSectionMap(pipeline_conf, "CAPTURE")['key']), 0), 'x')
    kfile_prefix = ConfigSectionMap(pipeline_conf, "CAPTURE")['kfname_prefix']
    kfname       = "{:s}_beam{:02d}_part{:d}.key".format(kfile_prefix, beam, part)
    nreader      = int(ConfigSectionMap(pipeline_conf, "CAPTURE")['nreader'])
     
    # Record the key to a key file with kfname
    kfile = open(kfname, "w")
    kfile.writelines("DADA INFO:\n")
    kfile.writelines("key {:s}\n".format(key))
    kfile.close()
    
    # Get system configuration from configuration file
    df_prd       = float(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['df_prd'])
    nsamp_df     = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['nsamp_df'])
    npol_samp    = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['npol_samp'])
    ndim_pol     = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['ndim_pol'])
    nbyte_dim    = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['nbyte_dim'])
    nchan_chk    = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['nchan_chk'])
    df_hdrsz     = int(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['df_hdrsz'])
    df_res       = float(ConfigSectionMap(system_conf, "EthernetInterfaceBMF")['df_res'])
    pktsz        = npol_samp * ndim_pol * nbyte_dim * nchan_chk * nsamp_df + df_hdrsz
    if hdr == 1:
        blksz     = ndf_blk * (nsamp_df * npol_samp * ndim_pol * nbyte_dim * nchan + df_hdrsz * nchan / nchan_chk)
    else:
        blksz   = ndf_blk * nsamp_df * npol_samp * ndim_pol * nbyte_dim * nchan
    
    # Check the connection
    destination_active, destination_dead = check_all_ports(destination, pktsz, df_prd, ndf_check)
    
    if (len(destination_active) == 0):
        print "There is no active port for beam {:02d}, have to abort ...".format(beam)
        exit(1)
    print "The active destination \"[IP_PORT_NCHUNK_EXPECT_NCHUNK_ACTUAL]\" are: ", destination_active
    print "The dead destination \"[IP_PORT_NCHUNK_EXPECT]\" are:                 ", destination_dead
    
    # Create PSRDADA buffer
    os.system("dada_db -l -p -k {:s} -b {:d} -n {:d} -r {:d}".format(key, blksz, nblk, nreader))

    # Get reference timestamp of capture
    refinfo = capture_reftime(destination_active[0], pktsz, df_res, system_conf)
    print "The reference timestamp \"(DF_SEC, DF_IDF, UTC_START, MJD_START, PICOSECONDS)\"for current capture is: ", refinfo
    
    return destination_active, destination_dead, refinfo, key
