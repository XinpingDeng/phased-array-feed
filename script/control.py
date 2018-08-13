#!/usr/bin/env python

import socket
import os
import time
import parser
import argparse

# ./control.py -a 0 -b 0 -c START-OF-DATA:0:0
# ./control.py -a 0 -b 0 -c END-OF-DATA
# ./control.py -a 0 -b 0 -c STATUS-OF-TRAFFIC
# ./control.py -a 0 -b 0 -c END-OF-CAPTURE

parser = argparse.ArgumentParser(description='To control the capture')

parser.add_argument('-a', '--beam', type=int, nargs='+',
                    help='beam to control')
parser.add_argument('-b', '--part', type=int, nargs='+',
                    help='part to control')
parser.add_argument('-c', '--command', type=str, nargs='+',
                    help='command to send')

args    = parser.parse_args()
beam    = args.beam[0]
part    = args.part[0]
address = "capture.beam{:02d}part{:02d}.socket".format(beam, part)
command = args.command[0]

start_buf = 0
start_byte = 0 

sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
command_value = "{:s}:PSR J1939+2134:06 05 56.34:+23 23 40.00:{:d}:{:d}".format(command, start_buf, start_byte)  # To be safe, the RA and DEC should be "hh mm ss.ss" and "dd mm ss.ss"
#command_value = "{:s}:PSR J1939+2134:06 05 56.34:+23 23 40.00:{:d}".format(command, start_byte)
print command_value
sock.sendto("{:s}\n".format(command_value), address)
sock.close()