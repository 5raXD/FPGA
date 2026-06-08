`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Top
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Top level of Task 1 (see Figure 1 of the PDF). Instantiates
//                  Ps2_Interface (slow PS2Clk domain) and Ps2_Display (fast
//                  100 MHz domain) and connects them to the FPGA pins.
//
//                  The board push-button btnC (pin U18) is an ACTIVE-HIGH signal,
//                  while both sub-modules use an ACTIVE-LOW reset (rstn). Figure 1
//                  shows this inversion ("~reset"), which we do here since an XDC
//                  cannot invert a pin.
//
// Dependencies:    Ps2_Interface, Ps2_Display, Seg_7_Display
//
// Revision:        1.0
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Top(
    input  wire       clk,        // W5  - 100 MHz system clock
    input  wire       reset,      // U18 - btnC, active high (pressed = 1)
    input  wire       PS2Clk,     // C17 - keyboard clock
    input  wire       PS2Data,    // B17 - keyboard data
    output wire [6:0] seg,        // 7-segment cathodes
    output wire [3:0] an,         // 7-segment anodes
    output wire       dp,         // decimal point
    output wire       led         // U16 - strobe LED (LD0)
    );


endmodule
