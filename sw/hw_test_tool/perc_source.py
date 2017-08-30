#!/usr/bin/env python

#
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#


import os, sys, re, cmd, subprocess, shlex, time
from threading import Thread
from time import sleep, time

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from perc_test_lib import *
from threading import Thread

PKT_SIZE = 64
IFACE = "eth1"

#ETH_SRC = "08:11:11:11:11:08"
#ETH_DST = "08:22:22:22:22:08"

os.system('sudo ifconfig {0} 10.0.0.10 netmask 255.255.255.0'.format(IFACE))

TCPDUMP = subprocess.Popen(shlex.split("tcpdump -i {0} -w /dev/null".format(IFACE)))
time.sleep(0.1)

class PercSwitchTester(cmd.Cmd):
    """The PERC switch source end host implementation for HW testing"""

    prompt = "testing> "
    intro = "The PERC switch source end host implementation for HW testing"

    def __init__(self):
        cmd.Cmd.__init__(self)
        self.cur_flow_id = 0
        self.flow_threads = []
        os.system('rm -f *_src.log')

    def run_flow(self, pkt, duration):
        flowID = pkt.flowID
        fname = 'flow_{}_src.log'.format(flowID)
        with open(fname, 'w') as log:
            log.write("\nFlow {}:\n".format(flowID))
            log.write(self.sending_pkt_str(pkt.summary()))
            start_time = time()
            # send start flow packet
            pkt = srp1(pkt, iface=IFACE)
            log.write(self.received_pkt_str(pkt.summary()))
            # continue sending control packets
            while time() < start_time + duration:
                pkt = end_host_response(pkt, leave=0)
                log.write(self.sending_pkt_str(pkt.summary()))
                pkt = srp1(pkt, iface=IFACE)
                log.write(self.received_pkt_str(pkt.summary()))
            # send final leave packet
            pkt = end_host_response(pkt, leave=1)
            log.write(self.sending_pkt_str(pkt.summary()))
            sendp(pkt, iface=IFACE)

#            for i in range(num_rtts):
#                if i == num_rtts-1:
#                    pkt = end_host_response(pkt, leave=1)
#                    log.write(self.sending_pkt_str(pkt.summary()))
#                    sendp(pkt, iface=IFACE)
#                else:
#                    pkt = end_host_response(pkt, leave=0)
#                    log.write(self.sending_pkt_str(pkt.summary()))
#                    pkt = srp1(pkt, iface=IFACE)
#                    log.write(self.received_pkt_str(pkt.summary()))

    def sending_pkt_str(self, pkt_str):
        return """
Sending packet:
---------------
{}
""".format(pkt_str)

    def received_pkt_str(self, pkt_str):
        return """
Received packet:
----------------
{}
""".format(pkt_str)

    def do_start_flows(self, line):
        try:
            args = line.split()
            num_flows = int(args[0])
            duration = float(args[1])
        except:
            print >> sys.stderr,  "ERROR: start_flow usage\n", self.help_start_flow()
            sys.exit(1)

        # launch the flows
        for i in range(num_flows):
            start_pkt = start_flow_pkt('nf0', 'nf1', self.cur_flow_id, insert_timestamp=1) 
            self.cur_flow_id += 1
            run_flow_thread = Thread(target = self.run_flow, args = (start_pkt, duration, ))
            run_flow_thread.start()
            self.flow_threads.append(run_flow_thread)
            sleep(0.25) 

        # wait for flows to complete
        for thread in self.flow_threads:
            thread.join()
        print "All flows complete!"

    def help_start_flows(self):
        print """
start_flow [num_flows] [duration (seconds)]
Description: starts the desired number of flows, each lasting duration seconds
"""
    def do_exit(self, line):
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
        sys.exit(0)

    def do_EOF(self, line):
        print ""
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
        return True

if __name__ == '__main__':
    if len(sys.argv) > 1:
        PercSwitchTester().onecmd(' '.join(sys.argv[1:]))
        if (TCPDUMP.poll() is None):
            TCPDUMP.terminate()
    else:
        PercSwitchTester().cmdloop()
