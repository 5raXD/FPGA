`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/19/2026
// Design Name:     FPGA Lab 6 - VGA
// Module Name:     Drawer
// Project Name:    lab6
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Pixel color/drawing logic for the VGA display
//
//
//////////////////////////////////////////////////////////////////////////////////

module Drawer(
    input  wire        clk,
    input  wire        reset,
    input  wire [11:0] sw,
    input  wire        btnu,
    input  wire        btnd,
    input  wire        btnl,
    input  wire        btnr,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    output reg  [11:0] pixel_color
    );
    
endmodule
