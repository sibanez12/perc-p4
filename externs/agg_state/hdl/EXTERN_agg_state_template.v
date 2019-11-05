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
 * agg_state
 *
 * This is an atom to implement the atomic operation needed to updated 
 * sum_sat, num_sat, and num_flows state in the PERC algorithm.
 *
 * If statefulValid == 0 then return on next cycle (this is a data packet).
 * Otherwise do the full processing.
 *
 */

`timescale 1 ps / 1 ps

`define INACTIVE  2'd0
`define SAT       2'd1
`define UNSAT     2'd2
`define NEW_FLOW  2'd3

`define REG_NEW_LABEL_DEFAULT    'd0
`define REG_NEW_ALLOC_DEFAULT    'd0
`define REG_SUM_SAT_DEFAULT      'd0
`define REG_NUM_SAT_DEFAULT      'd0
`define REG_NUM_FLOWS_DEFAULT    'd0

// linkCap = 2^31
`define REG_LINK_CAP_DEFAULT     'h80000000


module @MODULE_NAME@ 
#(
    parameter BUF_DEPTH_BITS = 9, // buffer can hold 2^9 = 512 requests
    parameter LABEL_WIDTH = 2,
    parameter INDEX_WIDTH = 2,
    parameter REG_WIDTH = @REG_WIDTH@,
    parameter C_S_AXI_ADDR_WIDTH = @ADDR_WIDTH@,
    parameter C_S_AXI_DATA_WIDTH = 32
)
(
    // Data Path I/O
    input                                               clk_lookup,
    input                                               clk_lookup_rst_high, 
    input                                               tuple_in_@EXTERN_NAME@_input_VALID,
    input   [2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH+1:0]   tuple_in_@EXTERN_NAME@_input_DATA,
    output                                              tuple_out_@EXTERN_NAME@_output_VALID,
    output  [5*REG_WIDTH+LABEL_WIDTH:0]                 tuple_out_@EXTERN_NAME@_output_DATA,

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
        [2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH+1]                           : statefulValid_in
        [2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH]                             : leave_in
        [2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH-1 : 2*REG_WIDTH+LABEL_WIDTH] : index_in
        [2*REG_WIDTH+LABEL_WIDTH-1             : 2*REG_WIDTH]             : label_in
        [2*REG_WIDTH-1                         : REG_WIDTH]               : alloc_in
        [REG_WIDTH-1                           : 0]                       : demand_in

*/

/* Tuple format for output: 
        [] : bufFull_out
        [] : newLabel_out
        [] : newAlloc_out     // needs adjusting if newLabel_out == UNSAT
        [] : sumSatAdj_out    \
        [] : numSatAdj_out     | Used to calculate:
        [] : numFlowsAdj_out   |   R = (C - sumSatAdj)/(numFlowsAdj - numSatAdj)
        [] : linkCap_out      /

*/

    // convert the input data to readable wires
    wire                              statefulValid_in = tuple_in_@EXTERN_NAME@_input_DATA[2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH+1];
    wire                                    valid_in   = tuple_in_@EXTERN_NAME@_input_VALID;
    wire                                      leave_in = tuple_in_@EXTERN_NAME@_input_DATA[2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH];
    wire    [INDEX_WIDTH-1:0]               index_in   = tuple_in_@EXTERN_NAME@_input_DATA[2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH-1 : 2*REG_WIDTH+LABEL_WIDTH];
    wire    [LABEL_WIDTH-1:0]                label_in  = tuple_in_@EXTERN_NAME@_input_DATA[2*REG_WIDTH+LABEL_WIDTH-1 : 2*REG_WIDTH];
    wire    [REG_WIDTH-1:0]                  alloc_in  = tuple_in_@EXTERN_NAME@_input_DATA[2*REG_WIDTH-1 : REG_WIDTH];
    wire    [REG_WIDTH-1:0]                 demand_in  = tuple_in_@EXTERN_NAME@_input_DATA[REG_WIDTH-1 : 0];


    // final registers
    reg valid_final_r;
    reg buf_full_final_r;
    reg [LABEL_WIDTH-1:0]  newLabel_final_r;
    reg [REG_WIDTH-1:0]    newAlloc_final_r;
    reg [REG_WIDTH-1:0]    sumSatAdj_final_r;
    reg [REG_WIDTH-1:0]    numSatAdj_final_r;
    reg [REG_WIDTH-1:0]    numFlowsAdj_final_r;

    localparam REG_DEPTH = 2**INDEX_WIDTH;

    // registers to hold statefulness
    integer             i;
    reg     [REG_WIDTH-1:0]      linkCap_r;
    reg     [REG_WIDTH-1:0]      sumSat_r[REG_DEPTH-1:0];
    reg     [REG_WIDTH-1:0]      numSat_r[REG_DEPTH-1:0];
    reg     [REG_WIDTH-1:0]      numFlows_r[REG_DEPTH-1:0];

    // pipeline registers
    reg [REG_WIDTH-1:0]  small_op_reg;
    reg [REG_WIDTH-1:0]  large_op_reg;
    reg [0:0]            leave_reg[1:0];
    reg [REG_WIDTH+8:0]  mult_result_reg;
    reg [REG_WIDTH-1:0]  demand_reg[1:0];
    reg [REG_WIDTH-1:0]  oldLabel_reg[1:0];
    reg [REG_WIDTH-1:0]  index_reg[1:0];
    reg [REG_WIDTH-1:0]  oldAlloc_reg[1:0];
    reg [0:0]            valid_reg[1:0];
    reg [REG_WIDTH-1:0]  sumSatAdj_reg[1:0];
    reg [REG_WIDTH-1:0]  numSatAdj_reg[1:0];
    reg [REG_WIDTH-1:0]  numFlowsAdj_reg[1:0];
    reg [0:0]            statefulValid_reg[1:0];

    // wires for combinational logic
    reg [LABEL_WIDTH-1:0]  oldLabel;
    reg [REG_WIDTH-1:0]    oldAlloc;
    reg [LABEL_WIDTH-1:0]  newLabel;
    reg [REG_WIDTH-1:0]    newAlloc;
    reg [REG_WIDTH-1:0]    sumSatAdj;
    reg [REG_WIDTH-1:0]    numSatAdj;
    reg [REG_WIDTH-1:0]    numFlowsAdj;
    reg [REG_WIDTH-1:0]    newSumSat;
    reg [REG_WIDTH-1:0]    newNumSat;
    reg [REG_WIDTH-1:0]    newNumFlows;
    reg [REG_WIDTH-1:0] large_op;
    reg [REG_WIDTH-1:0] small_op;
    reg [REG_WIDTH+8:0] v0;
    reg [REG_WIDTH+8:0] v1;
    reg [REG_WIDTH+8:0] v2;
    reg [REG_WIDTH+8:0] v3;
    reg [REG_WIDTH+8:0] v4;
    reg [REG_WIDTH+8:0] v5;
    reg [REG_WIDTH+8:0] v6;
    reg [REG_WIDTH+8:0] mult_result;

    // wires for request_buffer
    wire                              statefulValid_buf;
    wire                              leave_buf;
    wire    [INDEX_WIDTH-1:0]         index_buf;
    wire    [LABEL_WIDTH-1:0]         label_buf;
    wire    [REG_WIDTH-1:0]           alloc_buf;
    wire    [REG_WIDTH-1:0]           demand_buf;
    wire                              buf_full;
    wire                              buf_empty;
    reg                               buf_rd_en;

    // state machine wires and regs
    localparam WAIT = 0;
    localparam PROCESS_CONTROL = 1;
    reg [1:0] state;
    reg [1:0] state_next;
    reg       valid_pipe_in;   // input to the pipeline of valid registers
    reg       valid_final_in;  // input to the final valid output register

    // control signals
    // CPU reads IP interface
    wire      [C_S_AXI_DATA_WIDTH-1:0]         ip2cpu_@PREFIX_NAME@_reg_data;
    wire      [C_S_AXI_ADDR_WIDTH-1:0]         ip2cpu_@PREFIX_NAME@_reg_index;
    wire                                       ip2cpu_@PREFIX_NAME@_reg_valid;

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
      .cpu2ip_@PREFIX_NAME@_reg_data          (),
      .cpu2ip_@PREFIX_NAME@_reg_index         (),
      .cpu2ip_@PREFIX_NAME@_reg_valid         (),
      .cpu2ip_@PREFIX_NAME@_reg_reset         (),
      // Global Registers - user can select if to use
      .cpu_resetn_soft(),//software reset, after cpu module
      .resetn_soft    (),//software reset to cpu module (from central reset management)
      .resetn_sync    (resetn_sync)//synchronized reset, use for better timing
    );
    //// CPU REGS END ////

    // connect up CPU read signals
    assign ip2cpu_@PREFIX_NAME@_reg_data = {'d0, buf_full_final_r}; // only ever read the buf_full_final_r register
    assign ip2cpu_@PREFIX_NAME@_reg_index = 'd0;
    assign ip2cpu_@PREFIX_NAME@_reg_valid = 'd1;

    // buffer to store requests from control and data packets
    fallthrough_small_fifo
       #( .WIDTH(2*REG_WIDTH+LABEL_WIDTH+INDEX_WIDTH+2),
          .MAX_DEPTH_BITS(BUF_DEPTH_BITS))
     request_buffer
       (// Outputs
        .dout                           ({statefulValid_buf, leave_buf, index_buf, label_buf, alloc_buf, demand_buf}),
        .full                           (buf_full),
        .nearly_full                    (),
        .prog_full                      (),
        .empty                          (buf_empty),
        // Inputs
        .din                            ({statefulValid_in, leave_in, index_in, label_in, alloc_in, demand_in}),
        .wr_en                          (valid_in & ~buf_full),
        .rd_en                          (buf_rd_en),
        .reset                          (~resetn_sync),
        .clk                            (clk_lookup));

    /*  state machine to drain request_buffer */
    always @(*) begin
        state_next = state;
        buf_rd_en = 0;
        valid_pipe_in = 0;
        valid_final_in = valid_reg[1];  // default connected to end of pipeline valid regs

        case(state)
            WAIT: begin
                if (~buf_empty) begin
                    if (statefulValid_buf) begin
                        // control packet
                        state_next = PROCESS_CONTROL;
                        valid_pipe_in = 1;  // kick off control packet processing
                    end else begin
                        // data packet
                        buf_rd_en = 1;      // move to next request
                        valid_final_in = 1; // data packets processed in 1 cycle
                    end
                end
            end

            PROCESS_CONTROL: begin
                if (valid_reg[1]) begin // control pkt processing is finished 
                    state_next = WAIT;
                    buf_rd_en = ~buf_empty;     // move to next request if available
                end 
            end

        endcase // case(state)
    end

    always @(posedge clk_lookup) begin
        if (~resetn_sync) begin
            state <= WAIT;
        end else begin
            state <= state_next;
        end
    end

    always @(*) begin
        /*********************************/
        /********** First Cycle **********/
        /*********************************/
        oldLabel = label_buf;
        oldAlloc = alloc_buf;

        // treat flows as UNSAT
        sumSatAdj = (label_buf == `SAT) ? (sumSat_r[index_buf] - alloc_buf)  : sumSat_r[index_buf]; 
        numSatAdj = (label_buf == `SAT) ? (numSat_r[index_buf] - 1)          : numSat_r[index_buf];

        // account for this flow if it is new
        numFlowsAdj = (label_buf == `NEW_FLOW) ? (numFlows_r[index_buf] + 1) : numFlows_r[index_buf];

        // perform multiplication
        large_op = demand_buf;
        small_op = numFlowsAdj - numSatAdj;

        /**********************************/
        /********** Second Cycle **********/
        /**********************************/
        v0 = (small_op_reg[0]) ?  large_op_reg      : 0;
        v1 = (small_op_reg[1]) ? (large_op_reg<<1) : 0;
        v2 = (small_op_reg[2]) ? (large_op_reg<<2) : 0;
        v3 = (small_op_reg[3]) ? (large_op_reg<<3) : 0;
        v4 = (small_op_reg[4]) ? (large_op_reg<<4) : 0;
        v5 = (small_op_reg[5]) ? (large_op_reg<<5) : 0;
        v6 = (small_op_reg[6]) ? (large_op_reg<<6) : 0;
        mult_result = v0 + v1 + v2 + v3 + v4 + v5 + v6;

        /*********************************/
        /********** Third Cycle **********/
        /*********************************/
        // determine newLabel and newAlloc
        if (leave_reg[1] == 1) begin
            newLabel = `INACTIVE;
            newAlloc = -1;
        end else begin 
            if ((linkCap_r - sumSatAdj_reg[1]) <= mult_result_reg) begin
                // flow is UNSAT
                newLabel = `UNSAT;
                newAlloc = -1;  // unused, will update later once division is performed 
            end else begin
                // flow is SAT
                newLabel = `SAT;
                newAlloc = demand_reg[1];
            end
        end

        // compute new values for switch state based on newLabel and oldLabel
        if (oldLabel_reg[1] == `NEW_FLOW && (newLabel == `SAT || newLabel == `UNSAT))
            newNumFlows = numFlows_r[index_reg[1]] + 1;
        else if ((oldLabel_reg[1] == `SAT || oldLabel_reg[1] == `UNSAT) && newLabel == `INACTIVE)
            newNumFlows = numFlows_r[index_reg[1]] - 1;
        else
            newNumFlows = numFlows_r[index_reg[1]];

        if ((oldLabel_reg[1] == `NEW_FLOW || oldLabel_reg[1] == `UNSAT) && newLabel == `SAT) begin
            newSumSat = sumSat_r[index_reg[1]] + newAlloc;
            newNumSat = numSat_r[index_reg[1]] + 1;
        end else if (oldLabel_reg[1] == `SAT && newLabel == `SAT) begin
            newSumSat = sumSat_r[index_reg[1]] - oldAlloc_reg[1] + newAlloc;
            newNumSat = numSat_r[index_reg[1]];
        end else if (oldLabel_reg[1] == `SAT && (newLabel == `UNSAT || newLabel == `INACTIVE)) begin
            newSumSat = sumSat_r[index_reg[1]] - oldAlloc_reg[1];
            newNumSat = numSat_r[index_reg[1]] - 1;
        end else begin
            newSumSat = sumSat_r[index_reg[1]];
            newNumSat = numSat_r[index_reg[1]];
        end
    end


    // drive the registers
    always @(posedge clk_lookup) begin
        // pipeline registers
        valid_reg[0] <= valid_pipe_in; //(statefulValid_in) ? valid_in : 'd0;
        valid_reg[1] <= valid_reg[0];
        small_op_reg <= small_op;
        large_op_reg <= large_op;
        leave_reg[0] <= leave_buf;
        leave_reg[1] <= leave_reg[0];
        mult_result_reg <= mult_result;
        demand_reg[0] <= demand_buf;
        demand_reg[1] <= demand_reg[0];
        oldLabel_reg[0] <= oldLabel;
        oldLabel_reg[1] <= oldLabel_reg[0];
        index_reg[0] <= index_buf;
        index_reg[1] <= index_reg[0];
        oldAlloc_reg[0] <= oldAlloc;
        oldAlloc_reg[1] <= oldAlloc_reg[0];
        sumSatAdj_reg[0] <= sumSatAdj;
        sumSatAdj_reg[1] <= sumSatAdj_reg[0];
        numSatAdj_reg[0] <= numSatAdj;
        numSatAdj_reg[1] <= numSatAdj_reg[0];
        numFlowsAdj_reg[0] <= numFlowsAdj;
        numFlowsAdj_reg[1] <= numFlowsAdj_reg[0];
        statefulValid_reg[0] <= statefulValid_buf;
        statefulValid_reg[1] <= statefulValid_reg[0];

        if (~resetn_sync) begin
            // pipeline register valid signals
            statefulValid_reg[0] <= 'd0;
            statefulValid_reg[1] <= 'd0;
            valid_reg[0] <= 'd0;
            valid_reg[1] <= 'd0;

            valid_final_r         <= 'd0;
            buf_full_final_r      <= 'd0;
            newLabel_final_r      <= `REG_NEW_LABEL_DEFAULT;
            newAlloc_final_r      <= `REG_NEW_ALLOC_DEFAULT;
            sumSatAdj_final_r     <= `REG_SUM_SAT_DEFAULT;
            numSatAdj_final_r     <= `REG_NUM_SAT_DEFAULT;
            numFlowsAdj_final_r   <= `REG_NUM_FLOWS_DEFAULT;

            linkCap_r             <= `REG_LINK_CAP_DEFAULT;
            for (i = 0; i < REG_DEPTH; i = i+1) begin
                sumSat_r[i]     <= `REG_SUM_SAT_DEFAULT;
                numSat_r[i]     <= `REG_NUM_SAT_DEFAULT;
                numFlows_r[i]   <= `REG_NUM_FLOWS_DEFAULT;
            end

        end 
        else begin
            valid_final_r         <= valid_final_in; //(statefulValid_buf == 'd0 && ~buf_empty) ? 'd1 : valid_reg[1];
            buf_full_final_r      <= (buf_full_final_r) ? 1 : buf_full; // stay high if buffer ever goes full
            newLabel_final_r      <= newLabel;
            newAlloc_final_r      <= newAlloc; 
            sumSatAdj_final_r     <= sumSatAdj_reg[1];
            numSatAdj_final_r     <= numSatAdj_reg[1];
            numFlowsAdj_final_r   <= numFlowsAdj_reg[1];

            linkCap_r             <= linkCap_r;
            for (i = 0; i < REG_DEPTH; i = i+1) begin
                if (valid_reg[1] && statefulValid_reg[1] && i == index_reg[1]) begin
                    sumSat_r[i]     <= newSumSat;
                    numSat_r[i]     <= newNumSat;
                    numFlows_r[i]   <= newNumFlows;
                end else begin
                    sumSat_r[i]     <= sumSat_r[i];
                    numSat_r[i]     <= numSat_r[i]; 
                    numFlows_r[i]   <= numFlows_r[i];
                end
            end
        end
    end

    // Read the new value from the register
    wire bufFull_out = buf_full_final_r;
    wire [LABEL_WIDTH-1:0] newLabel_out  = newLabel_final_r;
    wire [REG_WIDTH-1:0] newAlloc_out    = newAlloc_final_r;
    wire [REG_WIDTH-1:0] sumSatAdj_out   = sumSatAdj_final_r;
    wire [REG_WIDTH-1:0] numSatAdj_out   = numSatAdj_final_r;
    wire [REG_WIDTH-1:0] numFlowsAdj_out = numFlowsAdj_final_r;
    wire [REG_WIDTH-1:0] linkCap_out     = linkCap_r;

    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_final_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = {bufFull_out, newLabel_out, newAlloc_out, sumSatAdj_out, numSatAdj_out, numFlowsAdj_out, linkCap_out};

endmodule

