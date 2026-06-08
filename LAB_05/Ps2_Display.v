`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Display
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Visual feedback for the PS/2 interface, running on the fast
//                  100 MHz system clock:
//                    * shows the two hex symbols of "scancode" on the two
//                      right-hand 7-segment digits (left two blank), latching the
//                      value until the next key press;
//                    * blinks "led" with one short, eye-visible strobe per press.
//
//                  Clock-Domain Crossing: scancode/keyPressed are produced in the
//                  slow PS2Clk domain. keyPressed is passed through a 3-FF
//                  synchroniser and edge-detected; scancode is sampled into this
//                  domain on that (already settled) pulse - a simple, safe data +
//                  valid CDC handshake.
//
// Dependencies:    Seg_7_Display
//
// Revision:        1.0
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Display(
    input  wire       clk,         // 100 MHz system clock
    input  wire       rstn,        // active-low reset
    input  wire       keyPressed,  // pulse from Ps2_Interface (slow domain)
    input  wire [7:0] scancode,    // byte from Ps2_Interface (slow domain)
    output wire [6:0] seg,         // 7-segment cathodes (active low)
    output wire [3:0] an,          // 4 digit anodes (active low)
    output wire       dp,          // decimal point
    output reg        led          // strobe LED, one visible blink per press
    );
    


endmodule
