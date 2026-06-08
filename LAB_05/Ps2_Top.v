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
// Description:     
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

    wire rstn = ~reset;
    wire keyPressed;
    wire [7:0] scancode;

    Ps2_Display u_display(
    .clk  (clk),
    .rstn (rstn),
    .keyPressed (keyPressed),
    .scancode   (scancode),
    .seg  (seg),
    .an   (an),
    .dp   (dp),
    .led  (led));

    Ps2_Interface u_interface(
    .PS2Clk   (PS2Clk),
    .rstn     (rstn),
    .PS2Data  (PS2Data),
    .scancode (scancode),
    .keyPressed (keyPressed));

endmodule
