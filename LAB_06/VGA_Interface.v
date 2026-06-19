`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/19/2026
// Design Name:     FPGA Lab 6 - VGA
// Module Name:     VGA_Interface
// Project Name:    lab6
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     VGA timing/sync generator
//
//
//////////////////////////////////////////////////////////////////////////////////

module VGA_Interface(
    input  wire        clk,
    input  wire        rstn,
    input  wire [11:0] pixel_color,
    output reg  [3:0]  vgaRed,
    output reg  [3:0]  vgaGreen,
    output reg  [3:0]  vgaBlue,
    output reg         Hsync,
    output reg         Vsync,
    output reg  [10:0] XCoord,
    output reg  [10:0] YCoord
    );

endmodule
