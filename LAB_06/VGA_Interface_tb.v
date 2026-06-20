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

    reg correct;

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

    localparam H_VISIBLE = 799, H_FRONT_PORCH = 855, H_SYNC_END = 975, H_TOTAL = 1039;
    localparam V_VISIBLE = 599, V_FRONT_PORCH = 636, V_SYNC_END = 642, V_TOTAL = 665;

    always @(posedge clk) begin
        pixel_color <= (XCoord <= H_VISIBLE && YCoord <= V_VISIBLE)? $random : 12'h000;
        correct <= ({vgaRed, vgaGreen, vgaBlue} == pixel_color) &&
                   (Hsync == ((XCoord > H_FRONT_PORCH) && (XCoord <= H_SYNC_END))) &&
                   (Vsync == ((YCoord > V_FRONT_PORCH) && (YCoord <= V_SYNC_END)));
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("VGA_Interface_tb.vcd");
            $dumpvars(0, VGA_Interface_tb);
        end

        clk         = 0;
        rstn        = 1;
        pixel_color = 12'h000;

        // reset
        #10; 
        rstn = 0;
        #10;
        rstn = 1;

        repeat (H_TOTAL * V_TOTAL) #10; // run for 1 frames
        $finish;
    end

endmodule
