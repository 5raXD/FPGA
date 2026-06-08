`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Interface
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     PS/2 keyboard receiver.
//                  Receives the serial PS/2 frames coming from the numeric
//                  keypad, extracts the 8-bit make-code (scancode) of the most
//                  recently pressed key and raises a one-(PS2Clk)-cycle pulse
//                  "keyPressed" at the moment the FIRST make-code packet of a new
//                  press is received.
//
//                  PS/2 frame (11 bits, sent LSB first, sampled on the falling
//                  edge of PS2Clk):
//                      bit 0      : start  (always 0)
//                      bit 1..8   : data D0..D7 (LSB first)
//                      bit 9      : parity (odd)  - ignored here
//                      bit 10     : stop   (always 1)
//
//                  The keyboard clock (PS2Clk) is NOT free running: it toggles
//                  only while a byte is being transmitted and is idle (high) the
//                  rest of the time. Therefore:
//                    * the whole logic of this module is clocked by PS2Clk;
//                    * the reset is ASYNCHRONOUS and active low (rstn), so the
//                      design can be reset even while PS2Clk is idle;
//                    * the packet is decoded ON the stop-bit edge (the last edge
//                      that the keyboard actually produces) - we never wait for an
//                      edge that comes AFTER the stop bit, because none does.
//
// Dependencies:    None
//
// Revision:        1.0
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Interface(
    input  wire       PS2Clk,      // keyboard clock - used AS A CLOCK here
    input  wire       rstn,        // active-low ASYNCHRONOUS reset
    input  wire       PS2Data,     // keyboard serial data
    output reg  [7:0] scancode,    // most recent make-code byte
    output reg        keyPressed   // 1-cycle pulse on the first make of a new press
    );


endmodule
