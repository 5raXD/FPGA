`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/19/2026
// Design Name:     FPGA Lab 6 - VGA
// Module Name:     VGA_Interface_tb
// Project Name:    lab6
//
//////////////////////////////////////////////////////////////////////////////////
module VGA_Interface_tb;

    reg clk;
    reg rstn;
    reg [11:0] pixel_color;
    wire [3:0] vgaRed;
    wire [3:0] vgaGreen;
    wire [3:0] vgaBlue;
    wire Hsync;
    wire Vsync;
    wire [10:0] XCoord;
    wire [10:0] YCoord;

    wire corrent;

    always #5 clk = ~clk; // 100 MHz clk

    VGA_Interface vga_if(
      // Inputs
      .clk(clk),
      .rstn(rstn),
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

    initial begin
        // Initialize Inputs
        clk = 0;
        rstn = 1;
        pixel_color = 12'h000;
        #10 rstn = 0; // Reset
        #10 rstn = 1;


        


        $finish;
    end

    

endmodule
