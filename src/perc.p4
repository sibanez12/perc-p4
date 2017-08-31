//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


#include <core.p4>
#include <sume_switch.p4>

/*
 * Template P4 project for SimpleSumeSwitch 
 *
 */

#define N 32
#define L 10
#define PERC_TYPE 0x1234
#define MAX_HOPS 2

#define INACTIVE  2w0
#define SAT       2w1
#define UNSAT     2w2
#define NEW_FLOW  2w3

// send all control packets to nf3 
#define CTRL_PORT 8w0b01000000
#define TIMER_WIDTH 64
typedef bit<TIMER_WIDTH> timerVal_t;

typedef bit<48> EthAddr_t; 
typedef bit<N> PercInt_t;

// // timestamp generation
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(0)
// extern void tin_timestamp(in bit<1> valid, out timerVal_t result);

// #define REG_READ 8w0
// #define REG_WRITE 8w1
// // bufFull register
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(1)
// extern void bufFull_reg_rw(in bit<1> index,
//                            in bit<1> newVal,
//                            in bit<8> opCode,
//                            out bit<1> result);

// // linkCap register
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(1)
// extern void linkCap_reg_rw(in bit<1> index,
//                            in PercInt_t newVal,
//                            in bit<8> opCode,
//                            out PercInt_t result);
// 
// // timeout register
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(1)
// extern void timeout_reg_rw(in bit<1> index,
//                            in timerVal_t newVal,
//                            in bit<8> opCode,
//                            out timerVal_t result);

/*
 * - 3 cycles to process each ctrl pkt
 * - At most 100 ctrl pkts in buffer at same time
 * - Takes 300 cycles to process all of those ctrl pkts
 * - In those 300 cycles another 300 data pkts can arrive
 * - buffer must be able to hold at least 400 requests
 * - max latency = 300 (for 100 ctrl pkts) + 300 (for data pkts) = 600
 */
@Xilinx_MaxLatency(600) // 3 (for control pkts), but if the buffer is empty then 2 cycles for empty to go low...
@Xilinx_ControlWidth(1) // can read buf_full
extern void aggState_agg_state(in bit<1> leave_in,
                           in bit<2> index_in,
                           in bit<2> label_in,
                           in PercInt_t alloc_in,
                           in PercInt_t demand_in,
                           out bit<1> bufFull_out,
                           out bit<2> newLabel_out,
                           out PercInt_t newAlloc_out,
                           out PercInt_t sumSatAdj_out,
                           out PercInt_t numSatAdj_out,
                           out PercInt_t numFlowsAdj_out,
                           out PercInt_t linkCap_out);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(1) // can read/write timeoutVal
extern void maxSat_max_sat(in bit<2> index_in,
                            in bit<2> newLabel_in,
                            in PercInt_t newAlloc_in,
                            out timerVal_t timestamp_out,
                            out PercInt_t newMaxSat_out);

// standard Ethernet header
header Ethernet_h { 
    EthAddr_t dstAddr; 
    EthAddr_t srcAddr; 
    bit<16> etherType;
}

// generic perc header for both data and control pkts
header Perc_generic_h {
    PercInt_t flowID;
    bit<8> isControl; 
}

// perc header for control pkts
header Perc_control_h {
    bit<8> leave;
    bit<8> isForward;
    bit<8> hopCnt;
    bit<8> bottleneck_id;
    PercInt_t demand;
    bit<8> insert_debug;
    timerVal_t timestamp;
    bit<8> label_0;
    bit<8> label_1;
    bit<8> label_2;
    PercInt_t alloc_0;
    PercInt_t alloc_1;
    PercInt_t alloc_2;
    PercInt_t linkCap;
    PercInt_t sumSatAdj;
    PercInt_t numFlowsAdj;
    PercInt_t numSatAdj;
    PercInt_t newMaxSat;
    PercInt_t R;
}

// List of all recognized headers
struct Parsed_packet { 
    Ethernet_h ethernet; 
    Perc_generic_h perc_generic;
    Perc_control_h perc_control;
}

// user defined metadata: can be used to shared information between
// TopParser, TopPipe, and TopDeparser 
struct user_metadata_t {
    bit<8>  unused;
}

// digest data to be sent to CPU if desired. MUST be 80 bits!
struct digest_data_t {
    bit<80>  unused;
}

// Parser Implementation
@Xilinx_MaxPacketRegion(16384)
parser TopParser(packet_in b, 
                 out Parsed_packet p, 
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {
    state start {
        b.extract(p.ethernet);
        user_metadata.unused = 0;
        digest_data.unused = 0;
        transition select(p.ethernet.etherType) {
            PERC_TYPE: parse_perc_generic;
            default: accept;
        } 
    }

    state parse_perc_generic { 
        b.extract(p.perc_generic);
        transition select(p.perc_generic.isControl) {
            1 : parse_perc_control;
            default: accept;
        } 
    }

    state parse_perc_control {
        b.extract(p.perc_control);
        transition accept;
    }

}

// match-action pipeline
control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata, 
                inout digest_data_t digest_data, 
                inout sume_metadata_t sume_metadata) {

    /************* Ethernet forwarding *************/

    port_t dst_port;

    action set_output_port(port_t port) {
        dst_port = port;
    }

    action set_default_output_port() {
        dst_port = 8w0;
    }

    table forward {
        key = { p.ethernet.dstAddr: exact; }

        actions = {
            set_output_port;
            set_default_output_port;
        }
        size = 64;
        default_action = set_default_output_port;
    }

    /************* port to index map *************/

    bit<8> port;  // src_port or dst_port depeneding on whether fwd or rvs ctrl pkt
    bit<2> index; // the index to use to access state variables in externs

    action set_index(bit<2> val) {
        index = val;
    }

    action set_index_default() {
        index = 0;
    }

    table port_index_map {
        key = { port: exact; }

        actions = {
            set_index;
            set_index_default;
        }
        size = 64;
        default_action = set_index_default;
    }

    /************* division tables and metadata *************/

    PercInt_t numerator; 
    PercInt_t denominator;
    bit<L> log_num;
    bit<L> log_denom;
    bit<L> log_result;
    PercInt_t R;         // residual level

    action set_log_num(bit<L> result) {
        log_num = result;
    }

    action set_default_log_num() {
        log_num = 0;
    }

    table log_numerator {
        key = {
            numerator: ternary;
        }

        actions = {
            set_log_num;
            set_default_log_num;
        }
        size = 1024;
        default_action = set_default_log_num;
    }

    action set_log_denom(bit<L> result) {
        log_denom = result;
    }

    action set_default_log_denom() {
        log_denom = 0;
    }

    table log_denominator {
        key = {
            denominator: ternary;
        }

        actions = {
            set_log_denom;
            set_default_log_denom;
        }
        size = 1024;
        default_action = set_default_log_denom;
    }

    action set_default_result() {
        R = 0;
    }

    action set_result(bit<N> result) {
        R = result;
    }

    table exp {
        key = {
            log_result: exact;
        }

        actions = {
            set_result;
            set_default_result;
        }
        size = 4096;
        default_action = set_default_result;
    }

    /*******************************************************/

    apply {
        forward.apply();

        if (p.perc_control.isValid()) {
            // send to high priority queue
            sume_metadata.hp_dst_port = dst_port | CTRL_PORT; // copy to dedicated ctrl pkt port

            if (p.perc_control.isForward != 1) {
                p.perc_control.hopCnt = p.perc_control.hopCnt - 1;
                port = sume_metadata.src_port;
            } else {
                port = dst_port;
            }
            port_index_map.apply(); // compute index

            bit<2> label;
            PercInt_t alloc;
            // choose the correct label and alloc based on hopCnt
            if (p.perc_control.hopCnt == 0) {
                label = p.perc_control.label_0[1:0];
                alloc = p.perc_control.alloc_0;
            } else if (p.perc_control.hopCnt == 1) {
                label = p.perc_control.label_1[1:0];
                alloc = p.perc_control.alloc_1;               
            } else {
                label = p.perc_control.label_2[1:0];
                alloc = p.perc_control.alloc_2;
            }

            // Update sumSat, numSat, and numFlows
            bit<2> newLabel;
            PercInt_t newAlloc;
            PercInt_t sumSatAdj;
            PercInt_t numSatAdj;
            PercInt_t numFlowsAdj;
            PercInt_t linkCap;
            bit<1> bufFull;
            aggState_agg_state(p.perc_control.leave[0:0],
                              index,
                              label,
                              alloc,
                              p.perc_control.demand,
                              bufFull,
                              newLabel,
                              newAlloc,
                              sumSatAdj,
                              numSatAdj,
                              numFlowsAdj,
                              linkCap);
//            bit<1> bufFull_out;
//            if (bufFull == 1) {
//                bufFull_reg_rw(1w1, bufFull, REG_WRITE, bufFull_out);
//            }

            // update label and alloc with new values
            if (p.perc_control.hopCnt == 0) {
                p.perc_control.label_0 = 6w0++newLabel;
                p.perc_control.alloc_0 = newAlloc;
            } else if (p.perc_control.hopCnt == 1) {
                p.perc_control.label_1 = 6w0++newLabel;
                p.perc_control.alloc_1 = newAlloc;
            } else {
                p.perc_control.label_2 = 6w0++newLabel;
                p.perc_control.alloc_2 = newAlloc;
            }

            // Calculate Residual level (R)
            // num / denom = exp(log(num) - log(denom))
            numerator = linkCap - sumSatAdj;
            denominator = numFlowsAdj - numSatAdj;
            if (numerator == 0 || denominator == 0 || denominator > numerator) {
                R = 0;
            } else {
                log_numerator.apply();
                log_denominator.apply();
                log_result = log_num - log_denom;
                exp.apply();
            }

            // fill in new allocation if flow is UNSAT now
            if (newLabel == UNSAT && p.perc_control.hopCnt == 0) {
                p.perc_control.alloc_0 = R;
            } else if (newLabel == UNSAT && p.perc_control.hopCnt == 1) {
                p.perc_control.alloc_1 = R;
            } else if (newLabel == UNSAT && p.perc_control.hopCnt == 2) {
                p.perc_control.alloc_2 = R;
            }

            // perform maxSat update
            PercInt_t newMaxSat;
            timerVal_t curTime;
            maxSat_max_sat(index,
                            newLabel,
                            newAlloc,
                            curTime,
                            newMaxSat);

            if (p.perc_control.insert_debug == 1) {
                p.perc_control.timestamp = curTime;
                p.perc_control.linkCap = linkCap;
                p.perc_control.sumSatAdj = sumSatAdj;
                p.perc_control.numFlowsAdj = numFlowsAdj;
                p.perc_control.numSatAdj = numSatAdj;
                p.perc_control.newMaxSat = newMaxSat;
                p.perc_control.R = R;
            }

            // updated requested bandwidth if flow is active
            PercInt_t B; // bottleneck level
            if (p.perc_control.leave != 1) {
                // B = max(newMaxSat, R)
                if (newMaxSat > R) {
                    B = newMaxSat;
                } else {
                    B = R;
                }

                if (p.perc_control.bottleneck_id == p.perc_control.hopCnt) {
                    // update demand if this is the bottleneck link
                    p.perc_control.demand = B;
                } else if (p.perc_control.demand > B) {
                    p.perc_control.demand = B;
                    p.perc_control.bottleneck_id = p.perc_control.hopCnt;
                }
            }

            if (p.perc_control.isForward == 1) {
                p.perc_control.hopCnt = p.perc_control.hopCnt + 1;
            }
        } else {
            // is a data packet
            sume_metadata.lp_dst_port = dst_port; // send to low priority queue
        }

        if (p.ethernet.srcAddr == p.ethernet.dstAddr) {
            sume_metadata.lp_dst_port = 0;
            sume_metadata.hp_dst_port = 0;
        }

    }
}

// Deparser Implementation
@Xilinx_MaxPacketRegion(16384)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data, 
                    inout sume_metadata_t sume_metadata) { 
    apply {
        b.emit(p.ethernet); 
        b.emit(p.perc_generic); 
        b.emit(p.perc_control); 
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;

