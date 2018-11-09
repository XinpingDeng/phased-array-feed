#!/usr/bin/env python

import os, parser, argparse, ConfigParser, threading

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

def baseband2filterbank(args):    
    uid = 50000
    gid = 50000
    
    pipeline_conf = args.pipeline_conf[0]
    beam          = args.beam[0]
    part          = args.part[0]
    cpu           = args.cpu[0]

    ddir = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['dir']
    hdir = "/home/pulsar"
    
    dname                   = "phased-array-feed"
    #previous_container_name = "paf-capture.beam{:02d}part{:02d}".format(beam, part)
    previous_container_name = "paf-diskdb"
    current_container_name  = "paf-baseband2filterbank.beam{:02d}part{:02d}".format(beam, part)
    software_name           = "baseband2filterbank_main"
    
    ddir           = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['dir']
    key_capture    = ConfigSectionMap(pipeline_conf, "CAPTURE")['key']
    ndf_chk_rbuf   = int(ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['ndf_chk_rbuf'])
    key_b2f        = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['key']
    nstream        = int(ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['nstream'])
    ndf_chk_stream = int(ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['ndf_chk_stream'])
    nrepeat        = ndf_chk_rbuf / (ndf_chk_stream * nstream)

    dvolume = '{:s}:{:s}'.format(ddir, ddir)
    hvolume = '{:s}:{:s}'.format(hdir, hdir)

    com_line = "docker run --ipc=container:{:s} --rm -it --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all -e DISPLAY --net=host -v {:s} -v {:s} -u {:d}:{:d} --cap-add=IPC_LOCK --ulimit memlock=-1:-1 --name {:s} xinpingdeng/{:s} \"taskset -c {:d} /home/pulsar/xinping/phased-array-feed/src/baseband2filterbank/{:s} -a {:s} -b {:s} -c {:d} -d {:d} -e {:d} -f {:d} -g {:s}\"".format(previous_container_name, dvolume, hvolume, uid, gid, current_container_name, dname, cpu, software_name, key_capture, key_b2f, ndf_chk_rbuf, nrepeat, nstream, ndf_chk_stream, ddir)
    
    print com_line
    os.system(com_line)

def dada2filterbank(args):
    uid = 50000
    gid = 50000

    hdir          = "/home/pulsar"
    pipeline_conf = args.pipeline_conf[0]
    beam          = args.beam[0]
    part          = args.part[0]
    cpu           = args.cpu[1]
    #previous_container_name = "paf-capture.beam{:02d}part{:02d}".format(beam, part)
    previous_container_name = "paf-diskdb"
    current_container_name  = "paf-dada2filterbank"
    kfname_b2f              = "baseband2filterbank.beam{:02d}part{:02d}.key".format(beam, part)
    software_name           = "dada2filterbank_main"
    
    dname                   = "phased-array-feed"
    ddir                    = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['dir']
    key_b2f                 = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['key']
    dvolume                 = '{:s}:{:s}'.format(ddir, ddir)
    hvolume                 = '{:s}:{:s}'.format(hdir, hdir)
    
    #com_line = "docker run --rm -it --ipc=container:{:s} -v {:s} -u {:d}:{:d} --cap-add=IPC_LOCK --ulimit memlock=-1:-1 --name {:s} xinpingdeng/paf-base taskset -c {:d} dada_dada2filterbank -k {:s} -D {:s} -s".format(previous_container_name, dvolume, uid, gid, current_container_name, cpu, key_b2f, ddir)
    com_line = "docker run --rm -it --ipc=container:{:s} -v {:s} -v {:s} -u {:d}:{:d} --cap-add=IPC_LOCK --ulimit memlock=-1:-1 --name {:s} xinpingdeng/{:s} \"taskset -c {:d} /home/pulsar/xinping/phased-array-feed/src/dada2filterbank/{:s} -a {:s} -b /beegfs/DENG/AUG/try.fil -c {:s}\"".format(previous_container_name, dvolume, hvolume, uid, gid, current_container_name, dname, cpu, software_name, key_b2f, ddir)
    print com_line
    os.system(com_line)
    
# ./baseband2filterbank_dada2filterbank.py -a ../config/pipeline.conf -b 0 -c 0 -d 8 9

if __name__ == "__main__":    
    parser = argparse.ArgumentParser(description='To transfer data from shared memeory to disk with a docker container')
    parser.add_argument('-a', '--pipeline_conf', type=str, nargs='+',
                        help='The configuration of pipeline')    
    parser.add_argument('-b', '--beam', type=int, nargs='+',
                        help='The beam id from 0')
    parser.add_argument('-c', '--part', type=int, nargs='+',
                        help='The part id from 0')
    parser.add_argument('-d', '--cpu', type=int, nargs='+',
                        help='Bind threads to cpu')
    args          = parser.parse_args()
    
    t_dada2filterbank     = threading.Thread(target = dada2filterbank, args = (args,))
    t_baseband2filterbank = threading.Thread(target = baseband2filterbank, args = (args,))

    t_dada2filterbank.start()
    t_baseband2filterbank.start()

    t_dada2filterbank.join()
    t_baseband2filterbank.join()

    pipeline_conf = args.pipeline_conf[0]
    ddir = ConfigSectionMap(pipeline_conf, "BASEBAND2FILTERBANK")['dir']
