`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/19/2026
// Design Name:     FPGA Lab 6 - VGA
// Module Name:     VGA_Top
// Project Name:    lab6
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Top level of the VGA design
//
// Dependencies:    VGA_Interface, Drawer
//
//////////////////////////////////////////////////////////////////////////////////

module VGA_Top(
    // Inputs
    input  wire        clk,
    input  wire        reset,
    input  wire [11:0] sw,
    input  wire        btnu,
    input  wire        btnd,
    input  wire        btnl,
    input  wire        btnr,
    // Outputs
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync
    );

    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;

    VGA_Interface vga_if(
      // Inputs
      .clk(clk),
      .rstn(~reset),
      .pixel_color(pixel_color),
      // Outputs - to VGA pins
      .vgaRed(vgaRed),
      .vgaGreen(vgaGreen),
      .vgaBlue(vgaBlue),
      .Hsync(Hsync),
      .Vsync(Vsync),
      // Outputs - to Drawer
      .XCoord(XCoord),
      .YCoord(YCoord)
    );

    Drawer drawer(
      // Inputs
      .clk(clk),
      .reset(reset),
      .sw(sw),
      .btnu(btnu),
      .btnd(btnd),
      .btnl(btnl),
      .btnr(btnr),
      .XCoord(XCoord),
      .YCoord(YCoord),
      // Outputs
      .pixel_color(pixel_color)
    );

endmodule
