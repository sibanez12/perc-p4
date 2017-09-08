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

from nf_sim_tools import *
import random
from collections import OrderedDict
import sss_sdnet_tuples

import sys, os
sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/division'))
from div_impl import N,  make_tables
from perc_headers import *
from perc_test_lib import *
from switch_model import process_pkt


###########
# pkt generation tools
###########

pktsApplied = []
pktsExpected = []

# Pkt lists for SUME simulations
nf_applied = OrderedDict()
nf_applied[0] = []
nf_applied[1] = []
nf_applied[2] = []
nf_applied[3] = []
nf_expected = OrderedDict()
nf_expected[0] = []
nf_expected[1] = []
nf_expected[2] = []
nf_expected[3] = []

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "dma0":0b00000010}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}
nf_port_index_map = {0b00000001:0, 0b00000100:1, 0b00010000:2, 0b01000000:3}

sss_sdnet_tuples.clear_tuple_files()

def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt) 
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, hp_dst_port, lp_dst_port):
    assert(hp_dst_port == 0 or lp_dst_port == 0) # both cannot be set
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['hp_dst_port'] = hp_dst_port 
    sss_sdnet_tuples.sume_tuple_expect['lp_dst_port'] = lp_dst_port
    sss_sdnet_tuples.write_tuples()

    dst_port = hp_dst_port ^ lp_dst_port
    i = 0
    while dst_port != 0:
        if (dst_port & 1):
            if i == 3 and Perc_data in pkt:
                nf3_pkt = pkt.copy()
                nf3_pkt[Perc_data].payload = '\x00'*34  # trim data packet to 64 bytes
                nf_expected[i].append(nf3_pkt)
            else:
                nf_expected[i].append(pkt)
        dst_port = dst_port >> 2
        i += 1

def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    for i in nf_applied.keys():
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]

#####################
# generate testdata #
#####################

nf_mac_map = {"nf0":"08:11:11:11:11:08", "nf1":"08:22:22:22:22:08", "nf2":"08:33:33:33:33:08", "nf3":"08:44:44:44:44:08"}

i=0

def send_data(ingress, egress, flowID, num_pkts):
    global i
    for k in range(num_pkts):
        i+=1
        pkt = make_data_pkt(ingress, egress, flowID, 1500)
        applyPkt(pkt, ingress, i)
        resetMaxSat = False
        (pkt, hp_dst_port, lp_dst_port) = process_pkt(pkt, nf_port_map[ingress], resetMaxSat)
        # expect switch output pkt
        expPkt(pkt, hp_dst_port, lp_dst_port)

# set up the division tables
make_tables()

# send initial invalid ctrl pkt
ingress = "nf0"
egress = "nf1"
flowID = 0
pkt_f0 = start_flow_pkt(ingress, egress, flowID)
pkt_f0[Ether].src = pkt_f0[Ether].dst
applyPkt(pkt_f0, ingress, i)
resetMaxSat = False
(pkt_f0, hp_dst_port, lp_dst_port) = process_pkt(pkt_f0, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f0, hp_dst_port, lp_dst_port)

# start flow_0
ingress = "nf0"
egress = "nf1"
flowID = 0
pkt_f0 = start_flow_pkt(ingress, egress, flowID)
applyPkt(pkt_f0, ingress, i)
resetMaxSat = False
(pkt_f0, hp_dst_port, lp_dst_port) = process_pkt(pkt_f0, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f0, hp_dst_port, lp_dst_port)

ingress = "nf0"
egress = "nf1"
flowID = 0
send_data(ingress, egress, flowID, 10)

# start flow_1
i+=1
ingress = "nf2"
egress = "nf1"
flowID = 1
pkt_f1 = start_flow_pkt(ingress, egress, flowID)
applyPkt(pkt_f1, ingress, i)
resetMaxSat = False
(pkt_f1, hp_dst_port, lp_dst_port) = process_pkt(pkt_f1, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f1, hp_dst_port, lp_dst_port)

ingress = "nf2"
egress = "nf1"
flowID = 1
send_data(ingress, egress, flowID, 10)

# end host response for flow_0
i+=1
ingress = "nf1"
egress = "nf0"
pkt_f0 =  end_host_response(pkt_f0)
applyPkt(pkt_f0, ingress, i)
resetMaxSat = False
(pkt_f0, hp_dst_port, lp_dst_port) = process_pkt(pkt_f0, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f0, hp_dst_port, lp_dst_port)

ingress = "nf0"
egress = "nf1"
flowID = 0
send_data(ingress, egress, flowID, 10)

# end host response for flow_1
i+=1
ingress = "nf1"
egress = "nf2"
pkt_f1 =  end_host_response(pkt_f1)
applyPkt(pkt_f1, ingress, i)
resetMaxSat = False
(pkt_f1, hp_dst_port, lp_dst_port) = process_pkt(pkt_f1, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f1, hp_dst_port, lp_dst_port)

ingress = "nf2"
egress = "nf1"
flowID = 1
send_data(ingress, egress, flowID, 10)

# end host response for flow_0 (leave)
i+=1
ingress = "nf0"
egress = "nf1"
pkt_f0 =  end_host_response(pkt_f0, leave=1)
applyPkt(pkt_f0, ingress, i)
resetMaxSat = False
(pkt_f0, hp_dst_port, lp_dst_port) = process_pkt(pkt_f0, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f0, hp_dst_port, lp_dst_port)

# end host response for flow_1 (leave)
i+=1
ingress = "nf2"
egress = "nf1"
pkt_f1 =  end_host_response(pkt_f1, leave=1)
applyPkt(pkt_f1, ingress, i)
resetMaxSat = False
(pkt_f1, hp_dst_port, lp_dst_port) = process_pkt(pkt_f1, nf_port_map[ingress], resetMaxSat)
# expect switch output pkt
expPkt(pkt_f1, hp_dst_port, lp_dst_port)

write_pcap_files()

