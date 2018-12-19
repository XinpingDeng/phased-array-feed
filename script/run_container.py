#!/usr/bin/env python

import os, parser, argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run a docker container from mpifrpsr')
    parser.add_argument('-a', '--packet_name', type=str, nargs='+',
                    help='The name of packet to run')
    
    args        = parser.parse_args()
    packet_name = args.packet_name[0]
    
    os.system('docker run --rm -it --net=host -u 50000:50000 -e DISPLAY -v /home/pulsar:/home/pulsar -v /beegfs:/beegfs -v /tmp:/tmp --name {:s} xinpingdeng/{:s}'.format(packet_name, packet_name))