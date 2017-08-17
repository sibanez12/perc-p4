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


"""
Define the sume_metadata bus for SDNet simulations
"""

import collections

""" SDNet Tuple format:
   unused;            (88 bits)
   hp_dst_port;       (8 bits) 
   lp_dst_port;       (8 bits) 
   src_port;          (8 bits) 
   pkt_len;           (16 bits)
"""

sume_field_len = collections.OrderedDict()
sume_field_len['unused'] = 88
sume_field_len['hp_dst_port'] = 8
sume_field_len['lp_dst_port'] = 8
sume_field_len['src_port'] = 8
sume_field_len['pkt_len'] = 16

# initialize tuple_in
sume_tuple_in = collections.OrderedDict()
sume_tuple_in['unused'] = 0
sume_tuple_in['hp_dst_port'] = 0
sume_tuple_in['lp_dst_port'] = 0
sume_tuple_in['src_port'] = 0
sume_tuple_in['pkt_len'] = 0

#initialize tuple_expect
sume_tuple_expect = collections.OrderedDict()
sume_tuple_expect['unused'] = 0
sume_tuple_expect['hp_dst_port'] = 0
sume_tuple_expect['lp_dst_port'] = 0
sume_tuple_expect['src_port'] = 0
sume_tuple_expect['pkt_len'] = 0

