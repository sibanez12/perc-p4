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
This script generates the table entries for the ternary match tables that implement approximate
natural logarithm and the exact match table that implements exponentiation.
"""

from math import exp, log
from collections import OrderedDict
import sys, os

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/division'))
from div_impl import N, log_table, exp_table, make_tables

COMMANDS_FILE = "commands_div.txt"

def write_log_tables(f):
    for (addr, data, mask, val) in log_table:
        fmat = "table_tcam_add_entry log_numerator 0x{:08X} set_log_num 0b{:0%db}/0b{:0%db} => {}\n" % (N, N)
        cmd = fmat.format(addr, data, mask, val) 
        f.write(cmd)
    f.write('\n')

    for (addr, data, mask, val) in log_table:
        fmat = "table_tcam_add_entry log_denominator 0x{:08X} set_log_denom 0b{:0%db}/0b{:0%db} => {}\n" % (N, N)
        cmd = fmat.format(addr, data, mask, val) 
        f.write(cmd)   
    f.write('\n')

def write_exp_table(f):
    for key, value in exp_table:
        cmd = "table_cam_add_entry exp set_result {} => {}\n".format(key, value)
        f.write(cmd)
    f.write('\n')

def write_tables():
    with open(COMMANDS_FILE, 'w') as f:
        write_log_tables(f)
        write_exp_table(f)

def main():
    make_tables()
    write_tables()


if __name__ == '__main__':
    main()


