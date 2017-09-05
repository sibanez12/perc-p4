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

PERC_CONTROL = 0x1234
PERC_DATA = 0x1212
PERC_ACK = 0x1213

class Perc_data(Packet):
    name = "Perc_data"
    fields_desc = [
        BitField("flowID", 0, N), 
        BitField("index" , 0, N), 
        BitField("seqNo" , 0, N), 
        BitField("ackNo" , 0, N) 
    ]

    def answers(self, other):
        if isinstance(other, Perc_generic):
            if self.flowID == other.flowID:
                return 1 
        return 0

    def mysummary(self):
        return self.sprintf("""Perc_data:
\tflowID = %flowID%
\tindex = %index%
\tseqNo = %seqNo%
\tackNo = %ackNo%""")
   

class Perc_control(Packet):
     name = "Perc_control"
     fields_desc = [
         BitField("flowID", 0, N),
         BitField("leave", 0, 8),
         BitField("isForward", 0, 8),
         BitField("hopCnt", 0, 8),
         BitField("bottleneck_id", 0, 8),
         BitField("demand", 0, N),
         BitField("insert_debug", 0, 8),
         BitField("timestamp", 0, TIMER_WIDTH),
         ByteEnumField("label_0", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         ByteEnumField("label_1", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         ByteEnumField("label_2", 0, {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}),
         BitField("alloc_0", 0, N),
         BitField("alloc_1", 0, N),
         BitField("alloc_2", 0, N),
         BitField("linkCap", 0, N),
         BitField("sumSatAdj", 0, N),
         BitField("numFlowsAdj", 0, N),
         BitField("numSatAdj", 0, N),
         BitField("newMaxSat", 0, N),
         BitField("R", 0, N)
     ]

     def answers(self, other):
         if isinstance(other, Perc_control):
             if self.flowID == other.flowID:
                 return 1 
         return 0

     def mysummary(self):
         return self.sprintf("""Perc_control:
\tflowID = %flowID%
\tleave = %leave%
\tisForward = %isForward%
\thopCnt = %hopCnt%
\tbottleneck_id = %bottleneck_id%
\tdemand = %demand%
\tinsert_debug = %insert_debug%
\ttimestamp = %timestamp%
\tlabel_0 = %label_0%
\tlabel_1 = %label_1%
\tlabel_2 = %label_2%
\talloc_0 = %alloc_0%
\talloc_1 = %alloc_1%
\talloc_2 = %alloc_2%
\tlinkCap = %linkCap%
\tsumSatAdj = %sumSatAdj%
\tnumFlowsAdj = %numFlowsAdj%
\tnumSatAdj = %numSatAdj%
\tnewMaxSat = %newMaxSat%
\tR = %R%""")

bind_layers(Ether, Perc_control, type=PERC_CONTROL)
bind_layers(Ether, Perc_data, type=PERC_DATA)
bind_layers(Ether, Perc_data, type=PERC_ACK)
bind_layers(Perc_data, Raw)
bind_layers(Perc_control, Raw)

