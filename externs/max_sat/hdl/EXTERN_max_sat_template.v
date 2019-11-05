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
 * max_sat
 *
 * This is an atom to implement the atomic operation needed to updated 
 * max_sat and next_max_sat in the PERC algorithm. 
 *
 */

`timescale 1 ps / 1 ps

`define INACTIVE  2'd0
`define SAT       2'd1
`define UNSAT     2'd2
`define NEW_FLOW  2'd3

`define REG_MAX_SAT_DEFAULT        'd0
`define REG_NEXT_MAX_SAT_DEFAULT    'd0

// 20000*5ns = 100us
`define TIMEOUT_VAL 'd20000

module @MODULE_NAME@ 
#(
    parameter REG_WIDTH = @REG_WIDTH@,
    parameter TIMER_WIDTH = @TIMER_WIDTH@,
    parameter INDEX_WIDTH = 2,
    parameter LABEL_WIDTH = 2,
    parameter C_S_AXI_ADDR_WIDTH = @ADDR_WIDTH@,
    parameter C_S_AXI_DATA_WIDTH = 32
)
(
    // Data Path I/O
    input                                                        clk_lookup,
    input                                                        clk_lookup_rst_high, 
    input                                                        tuple_in_@EXTERN_NAME@_input_VALID,
    input   [REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH:0]                tuple_in_@EXTERN_NAME@_input_DATA,
    output                                                       tuple_out_@EXTERN_NAME@_output_VALID,
    output  [2*TIMER_WIDTH+REG_WIDTH-1:0]                        tuple_out_@EXTERN_NAME@_output_DATA,

    // Control Path I/O
    input                                     clk_control,
    input                                     clk_control_rst_low,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     control_S_AXI_AWADDR,
    input                                     control_S_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     control_S_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   control_S_AXI_WSTRB,
    input                                     control_S_AXI_WVALID,
    input                                     control_S_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     control_S_AXI_ARADDR,
    input                                     control_S_AXI_ARVALID,
    input                                     control_S_AXI_RREADY,
    output                                    control_S_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     control_S_AXI_RDATA,
    output     [1 : 0]                        control_S_AXI_RRESP,
    output                                    control_S_AXI_RVALID,
    output                                    control_S_AXI_WREADY,
    output     [1 :0]                         control_S_AXI_BRESP,
    output                                    control_S_AXI_BVALID,
    output                                    control_S_AXI_AWREADY

);


/* Tuple format for input: 
        [REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH]      : statefulValid_in
        [REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH-1:REG_WIDTH+LABEL_WIDTH]      : index_in
        [REG_WIDTH+LABEL_WIDTH-1:REG_WIDTH]      : newLabel_in
        [REG_WIDTH-1:0]      : newAlloc_in

*/

/* Tuple format for output: 
        [] : timestamp_out 
        [] : newMaxSat_out

*/

    // convert the input data to readable wires
    wire                              statefulValid_in     = tuple_in_@EXTERN_NAME@_input_DATA[REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH];
    wire                                  valid_in         = tuple_in_@EXTERN_NAME@_input_VALID;
    wire    [INDEX_WIDTH-1:0]             index_in         = tuple_in_@EXTERN_NAME@_input_DATA[REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH-1:REG_WIDTH+LABEL_WIDTH];
    wire    [LABEL_WIDTH-1:0]             newLabel_in      = tuple_in_@EXTERN_NAME@_input_DATA[REG_WIDTH+LABEL_WIDTH-1 : REG_WIDTH];
    wire    [REG_WIDTH-1:0]               newAlloc_in      = tuple_in_@EXTERN_NAME@_input_DATA[REG_WIDTH-1 : 0];

    // wires for combinational logic
    reg [REG_WIDTH-1:0]    newMaxSat;
    reg [REG_WIDTH-1:0]    newNextMaxSat;

    // final registers
    reg  valid_final_r;
    reg [REG_WIDTH-1:0]    newMaxSat_final_r;

    localparam REG_DEPTH = 2**INDEX_WIDTH;

    // registers to hold statefulness
    integer             i;
    reg     [TIMER_WIDTH-1:0]    ts_timer_r;  // non resetting timer
    reg     [TIMER_WIDTH-1:0]    timer_r;  // resetting timer
    reg     [TIMER_WIDTH-1:0]    timeoutVal_r;
    reg     [REG_WIDTH-1:0]      maxSat_r[REG_DEPTH-1:0];
    reg     [REG_WIDTH-1:0]      nextMaxSat_r[REG_DEPTH-1:0];

    // control signals
    // CPU reads IP interface
    wire      [C_S_AXI_DATA_WIDTH-1:0]         ip2cpu_@PREFIX_NAME@_reg_data;
    wire      [C_S_AXI_ADDR_WIDTH-1:0]         ip2cpu_@PREFIX_NAME@_reg_index;
    wire                                       ip2cpu_@PREFIX_NAME@_reg_valid;
//    wire      [C_S_AXI_ADDR_WIDTH-1:0]      ipReadReq_@PREFIX_NAME@_reg_index;
//    wire                                    ipReadReq_@PREFIX_NAME@_reg_valid;

    // CPU writes IP interface
    wire     [C_S_AXI_DATA_WIDTH-1:0]          cpu2ip_@PREFIX_NAME@_reg_data;
    wire     [C_S_AXI_ADDR_WIDTH-1:0]          cpu2ip_@PREFIX_NAME@_reg_index;
    wire                                       cpu2ip_@PREFIX_NAME@_reg_valid;
    wire                                       cpu2ip_@PREFIX_NAME@_reg_reset;

    wire resetn_sync;

    //// CPU REGS START ////
    @PREFIX_NAME@_cpu_regs
    #(
        .C_BASE_ADDRESS        (0),
        .C_S_AXI_DATA_WIDTH    (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH    (C_S_AXI_ADDR_WIDTH)
    ) @PREFIX_NAME@_cpu_regs_inst
    (
      // General ports
       .clk                    ( clk_lookup),
       .resetn                 (~clk_lookup_rst_high),
      // AXI Lite ports
       .S_AXI_ACLK             (clk_control),
       .S_AXI_ARESETN          (clk_control_rst_low),
       .S_AXI_AWADDR           (control_S_AXI_AWADDR),
       .S_AXI_AWVALID          (control_S_AXI_AWVALID),
       .S_AXI_WDATA            (control_S_AXI_WDATA),
       .S_AXI_WSTRB            (control_S_AXI_WSTRB),
       .S_AXI_WVALID           (control_S_AXI_WVALID),
       .S_AXI_BREADY           (control_S_AXI_BREADY),
       .S_AXI_ARADDR           (control_S_AXI_ARADDR),
       .S_AXI_ARVALID          (control_S_AXI_ARVALID),
       .S_AXI_RREADY           (control_S_AXI_RREADY),
       .S_AXI_ARREADY          (control_S_AXI_ARREADY),
       .S_AXI_RDATA            (control_S_AXI_RDATA),
       .S_AXI_RRESP            (control_S_AXI_RRESP),
       .S_AXI_RVALID           (control_S_AXI_RVALID),
       .S_AXI_WREADY           (control_S_AXI_WREADY),
       .S_AXI_BRESP            (control_S_AXI_BRESP),
       .S_AXI_BVALID           (control_S_AXI_BVALID),
       .S_AXI_AWREADY          (control_S_AXI_AWREADY),

      // Register ports
      // CPU reads IP interface
      .ip2cpu_@PREFIX_NAME@_reg_data              (ip2cpu_@PREFIX_NAME@_reg_data),
      .ip2cpu_@PREFIX_NAME@_reg_index             (ip2cpu_@PREFIX_NAME@_reg_index),
      .ip2cpu_@PREFIX_NAME@_reg_valid             (ip2cpu_@PREFIX_NAME@_reg_valid),
      .ipReadReq_@PREFIX_NAME@_reg_index       (),
      .ipReadReq_@PREFIX_NAME@_reg_valid       (),
      // CPU writes IP interface
      .cpu2ip_@PREFIX_NAME@_reg_data          (cpu2ip_@PREFIX_NAME@_reg_data),
      .cpu2ip_@PREFIX_NAME@_reg_index         (cpu2ip_@PREFIX_NAME@_reg_index),
      .cpu2ip_@PREFIX_NAME@_reg_valid         (cpu2ip_@PREFIX_NAME@_reg_valid),
      .cpu2ip_@PREFIX_NAME@_reg_reset         (cpu2ip_@PREFIX_NAME@_reg_reset),
      // Global Registers - user can select if to use
      .cpu_resetn_soft(),//software reset, after cpu module
      .resetn_soft    (),//software reset to cpu module (from central reset management)
      .resetn_sync    (resetn_sync)//synchronized reset, use for better timing
    );
    //// CPU REGS END ////

    // connect the CPU read interface
    assign ip2cpu_@PREFIX_NAME@_reg_data = timeoutVal_r[C_S_AXI_DATA_WIDTH-1:0]; // can read last 32 bits of the timeoutVal reg
    assign ip2cpu_@PREFIX_NAME@_reg_index = 'd0;
    assign ip2cpu_@PREFIX_NAME@_reg_valid = 'd1;

    // max_sat update logic 
    always @(*) begin
        if (timer_r > timeoutVal_r) begin
            if (newLabel_in == `SAT) begin
                // newMaxSat = max(newAlloc, nextMaxSat)
                newMaxSat = (newAlloc_in > nextMaxSat_r[index_in]) ? newAlloc_in : nextMaxSat_r[index_in];
            end else begin
                newMaxSat = nextMaxSat_r[index_in];
            end

            newNextMaxSat = 'd0;
        end
        else if (newLabel_in == `SAT) begin
            // newMaxSat = max(newAlloc, maxSat)
            newMaxSat = (newAlloc_in > maxSat_r[index_in]) ? newAlloc_in : maxSat_r[index_in];
            // newNextMaxSat = max(newAlloc, nextMaxSat)
            newNextMaxSat = (newAlloc_in > nextMaxSat_r[index_in]) ? newAlloc_in : nextMaxSat_r[index_in];
        end
        else begin
            newMaxSat = maxSat_r[index_in];
            newNextMaxSat = nextMaxSat_r[index_in]; 
        end

    end


    // drive the registers
    always @(posedge clk_lookup)
    begin
        if (~resetn_sync | cpu2ip_@PREFIX_NAME@_reg_reset) begin
            valid_final_r         <= 'd0;
            newMaxSat_final_r     <= 'd0; 

            ts_timer_r <= 'd0;
            timer_r <= 'd0;
            timeoutVal_r <=  `TIMEOUT_VAL;
            for (i = 0; i < REG_DEPTH; i = i+1) begin
                maxSat_r[i]        <= `REG_MAX_SAT_DEFAULT;
                nextMaxSat_r[i]    <= `REG_NEXT_MAX_SAT_DEFAULT;
            end
        end 
        else begin
            valid_final_r         <= valid_in;
            newMaxSat_final_r     <= newMaxSat;

            ts_timer_r <= ts_timer_r + 'd1; // non-resetting timer
            timer_r <= (timer_r > timeoutVal_r) ? 'd0 : timer_r + 'd1; // resetting timer
            for (i = 0; i < REG_DEPTH; i = i+1) begin
                if (valid_in && statefulValid_in && i == index_in) begin
                    maxSat_r[i]       <= newMaxSat;
                    nextMaxSat_r[i]   <= newNextMaxSat;
                end
                else begin
                    if (timer_r > timeoutVal_r) begin
                        maxSat_r[i]     <= nextMaxSat_r[i];
                        nextMaxSat_r[i] <= 'd0;
                    end
                    else begin
                        maxSat_r[i]       <= maxSat_r[i];
                        nextMaxSat_r[i]   <= nextMaxSat_r[i];
                    end
                end
            end

            // update the timeoutVal register from the control plane
            if (cpu2ip_@PREFIX_NAME@_reg_valid && cpu2ip_@PREFIX_NAME@_reg_index == 'd0) begin
                timeoutVal_r <= {'d0, cpu2ip_@PREFIX_NAME@_reg_data};
            end
            else begin
                timeoutVal_r <= timeoutVal_r;
            end
        end
    end

    // Read the new value from the register
    wire [TIMER_WIDTH-1:0] resetTimer_out = timer_r;
    wire [TIMER_WIDTH-1:0] timestamp_out = ts_timer_r;
    wire [REG_WIDTH-1:0]   newMaxSat_out  = newMaxSat_final_r;

    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_final_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = {resetTimer_out, timestamp_out, newMaxSat_out};

endmodule

