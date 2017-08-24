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


from scapy.all import *
import sys, os

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/division'))
from div_impl import N

TIMER_WIDTH = 64

INACTIVE = 0
SAT      = 1
UNSAT    = 2
NEW_FLOW = 3

PERC_TYPE = 0x1234

class Perc_generic(Packet):
    name = "Perc_generic"
    fields_desc = [
        BitField("flowID", 0, N),
        BitField("isControl", 0, 8)
    ]
   

class Perc_control(Packet):
     name = "Perc_control"
     fields_desc = [
         BitField("leave", 0, 8),
         BitField("isForward", 0, 8),
         BitField("hopCnt", 0, 8),
         BitField("bottleneck_id", 0, 8),
         BitField("demand", 0, N),
         BitField("insert_timestamp", 0, 8),
         BitField("timestamp", 0, TIMER_WIDTH),
         ByteEnumField("label_0", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         ByteEnumField("label_1", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         ByteEnumField("label_2", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         BitField("alloc_0", 0, N),
         BitField("alloc_1", 0, N),
         BitField("alloc_2", 0, N)
     ]

bind_layers(Ether, Perc_generic, type=PERC_TYPE)
bind_layers(Perc_generic, Perc_control, isControl=1)
bind_layers(Perc_generic, Raw, isControl=0)
bind_layers(Perc_control, Raw)

