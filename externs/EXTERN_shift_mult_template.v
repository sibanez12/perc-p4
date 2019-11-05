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


/*
 * File: @MODULE_NAME@.v 
 * Author: Stephen Ibanez
 * 
 * Auto-generated file.
 *
 * Perform Multiplication
 *
 */



`timescale 1 ps / 1 ps

module @MODULE_NAME@ 
#(
    parameter LARGE_OP_WIDTH = @LARGE_OP_WIDTH@,
    parameter SMALL_OP_WIDTH = @SMALL_OP_WIDTH@
)
(
    // Data Path I/O
    input                                   clk_lookup,
    input                                   rst, 
    input                                   tuple_in_@EXTERN_NAME@_input_VALID,
    input   [LARGE_OP_WIDTH+SMALL_OP_WIDTH:0]                           tuple_in_@EXTERN_NAME@_input_DATA,
    output                                  tuple_out_@EXTERN_NAME@_output_VALID,
    output  [LARGE_OP_WIDTH-1:0]               tuple_out_@EXTERN_NAME@_output_DATA

);


/* Tuple format for input: tuple_in_tin_timestamp_input
        [SMALL_OP_WIDTH+LARGE_OP_WIDTH    : SMALL_OP_WIDTH+LARGE_OP_WIDTH] : statefulValid_in
        [SMALL_OP_WIDTH+LARGE_OP_WIDTH-1  : SMALL_OP_WIDTH]   : large_op
        [SMALL_OP_WIDTH-1    : 0]         : small_op

*/

/* Tuple format for output: tuple_out_tin_timestamp_output
        [OP_WIDTH-1:0]  : result

*/

    // convert the input data to readable wires
    wire    statefulValid_in         = tuple_in_@EXTERN_NAME@_input_DATA[SMALL_OP_WIDTH+LARGE_OP_WIDTH];
    wire    valid_in                 = tuple_in_@EXTERN_NAME@_input_VALID;
    wire [LARGE_OP_WIDTH-1:0]    large_op_in    = tuple_in_@EXTERN_NAME@_input_DATA[SMALL_OP_WIDTH+LARGE_OP_WIDTH-1:SMALL_OP_WIDTH];
    wire [SMALL_OP_WIDTH-1:0]    small_op_in    = tuple_in_@EXTERN_NAME@_input_DATA[SMALL_OP_WIDTH-1:0];


    // registers to hold statefulness
    reg                                  valid_r;
    reg     [LARGE_OP_WIDTH-1:0]         result_r;

    // wires for combinational logic
    reg[LARGE_OP_WIDTH-1:0] v0;
    reg[LARGE_OP_WIDTH-1:0] v1;
    reg[LARGE_OP_WIDTH-1:0] v2;
    reg[LARGE_OP_WIDTH-1:0] v3;
    reg[LARGE_OP_WIDTH-1:0] v4;
    reg[LARGE_OP_WIDTH-1:0] v5;
    reg[LARGE_OP_WIDTH-1:0] v6;
    reg[LARGE_OP_WIDTH-1:0] mult_result;

    always @(*) begin

        v0 = (small_op_in[0]) ? large_op_in      : 0;
        v1 = (small_op_in[1]) ? (large_op_in<<1) : 0;
        v2 = (small_op_in[2]) ? (large_op_in<<2) : 0;
        v3 = (small_op_in[3]) ? (large_op_in<<3) : 0;
        v4 = (small_op_in[4]) ? (large_op_in<<4) : 0;
        v5 = (small_op_in[5]) ? (large_op_in<<5) : 0;
        v6 = (small_op_in[6]) ? (large_op_in<<6) : 0;

        mult_result = v0 + v1 + v2 + v3 + v4 + v5 + v6;

    end


    // drive the registers
    always @(posedge clk_lookup)
    begin
        if (rst) begin
            valid_r <= 1'd0;
            result_r <= 'd0;

        end else begin
            valid_r <= valid_in;
            result_r <= mult_result;
        end
    end

    // Read the new value from the register
    wire [LARGE_OP_WIDTH-1:0] result_out = result_r;

    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = {result_out};

endmodule


