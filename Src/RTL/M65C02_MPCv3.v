`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2009-2012 by Michael A. Morris, dba M. A. Morris & Associates
//
//  All rights reserved. The source code contained herein is publicly released
//  under the terms and conditions of the GNU Lesser Public License. No part of
//  this source code may be reproduced or transmitted in any form or by any
//  means, electronic or mechanical, including photocopying, recording, or any
//  information storage and retrieval system in violation of the license under
//  which the source code is released.
//
//  The souce code contained herein is free; it may be redistributed and/or 
//  modified in accordance with the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either version 2.1 of
//  the GNU Lesser General Public License, or any later version.
//
//  The souce code contained herein is freely released WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
//  PARTICULAR PURPOSE. (Refer to the GNU Lesser General Public License for
//  more details.)
//
//  A copy of the GNU Lesser General Public License should have been received
//  along with the source code contained herein; if not, a copy can be obtained
//  by writing to:
//
//  Free Software Foundation, Inc.
//  51 Franklin Street, Fifth Floor
//  Boston, MA  02110-1301 USA
//
//  Further, no use of this source code is permitted in any form or means
//  without inclusion of this banner prominently in any derived works. 
//
//  Michael A. Morris
//  Huntsville, AL
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates
// Engineer:        Michael A. Morris
// 
// Create Date:     12:02:40 10/28/2012 
// Design Name:     Microprogram Controller (Version 3)
// Module Name:     MPCv3.v
// Project Name:    C:\XProjects\VerilogComponents\MPCv3
// Target Devices:  Generic SRAM-based FPGA
// Tool versions:   Xilinx ISE 10.1i SP3
// 
// Description:
//
// This module implements a simple microprogram sequencer based on the Fair-
// child F9408. The sequencer provides:
//
//          (1) 4-bit instruction input
//          (2) four-level LIFO stack;
//          (3) program counter and incrementer;
//          (4) 4-bit registered test input;
//          (5) 8-way multi-way branch control input;
//          (6) branch address input;
//          (7) 4-way branch address select output;
//          (8) next address output.
//
// These elements provide a relatively flexible general purpose microprogram
// controller without a complex instruction set. The sixteen instructions can
// be categorized into three classes: (1) fetch, (2) unconditional branches,
// and (3) conditional branches. The fetch instruction class, a single instruc-
// tion class, simply increments the program counter and outputs the current
// value of the program counter on the next address bus. The unconditional 
// branch instruction class provides instructions to select the next instruc-
// tion using the Via[1:0] outputs and output that value on the next address
// bus and simultaneously load the program counter. The unconditional branch
// instruction class also provides for 8-way multiway branching using an exter-
// nal (priority) encoder/branch selector, and microprogram subroutine call and 
// return instructions.
//
// The instruction encodings of the F9408, as provided in "Principles of Firm-
// ware Engineering in Microprogram Control" by Michael Andrews. The instruc-
// tion set and operation map for the implementation is given below:
//
//  I[3:0] MNEM Definition       T[3:0]      MA[m:0]      Via Inh  Operation
//   0000  RTS  Return            xxxx      TOS[m:0]       00  0  PC<=MA;Pop
//   0001  BSR  Call Subroutine   xxxx       BA[m:0]       00  1  PC<=MA;Push
//   0010  FTCH Next Instruction  xxxx        PC+1         00  0  PC<=MA[m:0]
//   0011  BMW  Multi-way Branch  xxxx  {BA[m:3],MW[2:0]}  00  1  PC<=MA[m:0]
//   0100  BRV0 Branch Via 0      xxxx       BA[m:0]       00  1  PC<=MA[m:0]
//   0101  BRV1 Branch Via 1      xxxx       BA[m:0]       01  1  PC<=MA[m:0]
//   0110  BRV2 Branch Via 2      xxxx       BA[m:0]       10  1  PC<=MA[m:0]
//   0111  BRV3 Branch Via 3      xxxx       BA[m:0]       11  1  PC<=MA[m:0]
//   1000  BTH0 Branch T0 High    xxx1  {T0?BA[m:0]:PC+1}  00  1  PC<=MA[m:0]
//   1001  BTH1 Branch T1 High    xx1x  {T1?BA[m:0]:PC+1}  00  1  PC<=MA[m:0]
//   1010  BTH2 Branch T2 High    x1xx  {T2?BA[m:0]:PC+1}  00  1  PC<=MA[m:0]
//   1011  BTH3 Branch T3 High    1xxx  {T2?BA[m:0]:PC+1}  00  1  PC<=MA[m:0]
//   1100  BTL0 Branch T0 Low     xxx0  {T0?PC+1:BA[m:0]}  00  1  PC<=MA[m:0]
//   1101  BTL1 Branch T1 Low     xx0x  {T1?PC+1:BA[m:0]}  00  1  PC<=MA[m:0]
//   1110  BTL2 Branch T2 Low     x0xx  {T2?PC+1:BA[m:0]}  00  1  PC<=MA[m:0]
//   1111  BTL3 Branch T3 Low     0xxx  {T3?PC+1:BA[m:0]}  00  1  PC<=MA[m:0]
//
// Dependencies:    none.
//
// Revision: 
//
//  0.01    12J28   MAM     File Created
//
//  1.00    12K12   MAM     Modified MA multiplexer to either present next
//                          address or hold current address. This is required
//                          when the next microcycle has a length greater than
//                          one. To perform this adjustment/extension of the
//                          microcycle, two signals track the current and next
//                          microcycle length: CurLenZ, and NxtLenZ. Also, added
//                          register MPC_En to control the MPC registers and
//                          MA multiplexer. Removed non-pipelined mode control
//                          input because the typical usage of the MPC is with
//                          Block RAM, which will only work with the pipelined
//                          mode.
//
// Additional Comments: 
//
//  The Version 3 Microprogram Controller (MPCv3) is based on the Fairchild
//  F9408 MPC. It extends that microprogram controller by incorporating a micro-
//  cycle controller directly into the module, a al Am2925, which allows each
//  microcycle to be controlled by a field in the microprogram, or by external
//  logic.
//
//  The purpose of these extensions is to allow easy implementation of a varia-
//  ble length microprogram cycle, i.e. microcycle. In turn, this simplifies the
//  implementation of microprogrammed state machines which interface to synchro-
//  nous memories found in most FPGAs, or to external synchronous/asynchronous
//  memories.
//
//  When a microprogrammed state machine interfaces to a synchronous memory,
//  there is a one cycle delay between the presentation of the address and the
//  output of the data at that address. In many instances, the microprogram is
//  unable to perform any useful work during the first cycle. Thus, the micro-
//  program must perform an explicit delay operation, which generally requires
//  a state to be added to every read of these memories. If there are a signifi-
//  cant number of these read operations in the microprogram, then there is an
//  opportunity for the microprogram to be incorrectly programmed when one or
//  more of the delay cycles are not included in the microprogram. Isolating
//  the resulting fault in the state machine may be difficult.
//
//  To avoid errors of this type, microcycles which read from or write to 
//  devices, such as memories, can be automatically extended explicitly by a
//  microprogram field or logic. Using this type of facility reduces the number
//  of states required to interface a microprogrammed state machine to these
//  types of devices. It also makes the microprogram less tedious to develop and
//  improves overall productivity, which is a prime reason for choosing a micro-
//  programmed approach for developing complex state machines.
//
//  The objective of the embedded microcyle length controller is not to incor-
//  porate the full functionality of the Am2925 Microcycle Controller. Instead,
//  it is to add a simple microcycle length control function which can be used
//  to simplify the microprogram and provide a easy mechanism for interfacing
//  the microprogrammed state machine to devices which require more than one
//  clock cycle to access. The embedded microcycle length controller included in
//  this module allows the microcycle length of the F9408 to be set to 1 , 2,
//  or 4 cycles. When extended to 2 cycles, the cycle cannot be extended using
//  an external wait state request. When extended to 4 cycles, an external wait
//  state generator can be used to add any number of wait states to the micro-
//  cycle of the F9408.
//
///////////////////////////////////////////////////////////////////////////////

module M65C02_MPCv3 #(
    parameter pAddrWidth = 10,          // Original F9408 => 10-bit Address
    parameter pRst_Addrs = 0            // Reset Address
)(
    input   Rst,                        // Module Reset (Synchronous)
    input   Clk,                        // Module Clock

    input   [1:0] uLen,                 // Microcycle Length Select
    input   Wait,                       // Microcycle Wait State Request Input

    output  C4, C3, C2, C1,             // One-hot microcycle state outputs

    input   [3:0] I,                    // Instruction (see description)
    input   [3:0] T,                    // Conditional Test Inputs
    input   [2:0] MW,                   // Multi-way Branch Address Select
    input   [(pAddrWidth-1):0] BA,      // Microprogram Branch Address Field
    output  [1:0] Via,                  // Unconditional Branch Address Select


    output  reg [(pAddrWidth-1):0] MA   // Microprogram Address
);

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//
//  Local Parameters
//

localparam RTS  =  0;   // Return from Subroutine
localparam BSR  =  1;   // Branch to Subroutine
localparam FTCH =  2;   // Fetch Next Instruction
localparam BMW  =  3;   // Multi-way Branch
localparam BRV0 =  4;   // Branch Via External Branch Address Source #0
localparam BRV1 =  5;   // Branch Via External Branch Address Source #1
localparam BRV2 =  6;   // Branch Via External Branch Address Source #2
localparam BRV3 =  7;   // Branch Via External Branch Address Source #3
localparam BTH0 =  8;   // Branch if T[0] is Logic 1, else fetch next instr.
localparam BTH1 =  9;   // Branch if T[1] is Logic 1, else fetch next instr.
localparam BTH2 = 10;   // Branch if T[2] is Logic 1, else fetch next instr.
localparam BTH3 = 11;   // Branch if T[3] is Logic 1, else fetch next instr.
localparam BTL0 = 12;   // Branch if T[0] is Logic 0, else fetch next instr.
localparam BTL1 = 13;   // Branch if T[1] is Logic 0, else fetch next instr.
localparam BTL2 = 14;   // Branch if T[2] is Logic 0, else fetch next instr.
localparam BTL3 = 15;   // Branch if T[3] is Logic 0, else fetch next instr.

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//
//  Declarations
//

reg     [1:0] MC;                         // Microcycle Length Controller State
wire    NxtLenZ;                          // Next microcycle length is Z
reg     MPC_En;                           // MPC register enable

wire    [(pAddrWidth - 1):0] Next;        // Output Program Counter Incrementer
reg     [(pAddrWidth - 1):0] PC_In;       // Input to Program Counter
reg     [(pAddrWidth - 1):0] PC;          // Program Counter

reg     [(pAddrWidth - 1):0] A, B, C, D;  // LIFO Stack Registers

reg     dRst;                             // Reset stretcher
wire    MPC_Rst;                          // Internal MPC Reset signal

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

//  Implement module reset generator

always @(posedge Clk)
begin
    if(Rst)
        dRst <= #1 1;
    else
        dRst <= #1 0;
end

assign MPC_Rst = (Rst | dRst);

//
//  Embedded Microcycle Length Controller
//
//  Three microcycles are implemented: 1, 2, or 4 clock in length. If word 0 of
//  the microprogram, or external logic, sets a different length during reset,
//  the microcycle length controller will exit reset in either state 0 or
//  state 2. If it exits reset in state 2, a single clock microcycle will be
//  performed after reset. If it exits reset in state 0, either a 2 cycle or
//  a 4 cycle microcycle will be performed after reset. The microcycle length is
//  sampled in state 2, (C1 == 1). This allows either the microprogram or exter-
//  nal logic to control the length of each microcycle that the MPCv3 performs.

always @(posedge Clk)
begin
    if(MPC_Rst)
        MC <= #1 ((|uLen) ? 0 : 2);
    else
        case(MC)
            0 : MC <= #1 ((uLen[1]) ? 1 : 2);   // First cycle of microcycle
            1 : MC <= #1 ((Wait)    ? 1 : 3);   // 2nd of 4 cycle microcycle
            3 : MC <= #1 ((Wait)    ? 3 : 2);   // 3rd of 4 cycle microcycle
            2 : MC <= #1 ((|uLen)   ? 0 : 2);   // Last cycle of microcycle
        endcase
end

assign C4 = ~|MC;           // First cycle of microcycle (1 cycle in width)
assign C3 =  |MC;           // Strobe 1
assign C2 =   MC[1];        // Strobe 2
assign C1 =  (MC == 2);     // Last cycle of microcycle (initial state)

//  Assign next microcycle length

assign NxtLenZ = (uLen == 0);

//  Determine the MPC Enable signal

always @(posedge Clk)
begin
    if(MPC_Rst)
        MPC_En <= #1 1;
    else
        case(MC)
            2'b00 : MPC_En <= #1 ((uLen[1]) ? 0 : 1);
            2'b01 : MPC_En <= #1 0;
            2'b11 : MPC_En <= #1 ~Wait;
            2'b10 : MPC_En <= #1 NxtLenZ;
        endcase
end

//  Implement 4-Level LIFO Stack

always @(posedge Clk)
begin
    if(MPC_Rst)
        {A, B, C, D} <= #1 0;
    else if(MPC_En)
        if(I == BSR)
            {A, B, C, D} <= #1 {Next, A, B, C};
        else if(I == RTS)
            {A, B, C, D} <= #1 {B, C, D, {pAddrWidth{1'b0}}};
end

//  Program Counter Incrementer

assign Next = PC + 1;

//  Generate Unconditional Branch Address Select

assign Via = {((I == BRV2) | (I == BRV3)), ((I == BRV3) | (I == BRV1))};       

//  Generate Program Counter Input Signal

always @(*)
begin
    case({MPC_Rst, I})
        RTS     : PC_In <=  A;
        BSR     : PC_In <=  BA;
        FTCH    : PC_In <=  Next;
        BMW     : PC_In <=  {BA[(pAddrWidth - 1):3], MW};
        //
        BRV0    : PC_In <=  BA;
        BRV1    : PC_In <=  BA;
        BRV2    : PC_In <=  BA;
        BRV3    : PC_In <=  BA;
        //
        BTH0    : PC_In <=  (T[0] ? BA   : Next);
        BTH1    : PC_In <=  (T[1] ? BA   : Next);
        BTH2    : PC_In <=  (T[2] ? BA   : Next);
        BTH3    : PC_In <=  (T[3] ? BA   : Next);
        //
        BTL0    : PC_In <=  (T[0] ? Next : BA  );
        BTL1    : PC_In <=  (T[1] ? Next : BA  );
        BTL2    : PC_In <=  (T[2] ? Next : BA  );
        BTL3    : PC_In <=  (T[3] ? Next : BA  );
        default : PC_In <=  pRst_Addrs;
    endcase
end

//  Generate Microprogram Address (Program Counter)

always @(posedge Clk)
begin
    if(MPC_Rst)
        PC <= #1 pRst_Addrs;
    else if(MPC_En)
        PC <= #1 PC_In;
end

//  Assign Memory Address Bus

always @(*)
begin
    MA <= ((MPC_En) ? PC_In : PC);
end

endmodule