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
        // correct <= 
        
        // ((XCoord <= 799) && (YCoord <= 599) ? pixel_color : 12'h000
        //          && (XCoord <= 799) && (YCoord <= 599) ? 1'b1 : 1'b0);
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("VGA_Interface_tb.vcd");
            $dumpvars(0, VGA_Interface_tb);
        end

        clk         = 0;
        rstn        = 1;
        pixel_color = 12'hAF3;

        // reset
        #10 rstn = 0;
        #20 rstn = 1;

        // run ~2 horizontal lines (1 line = 1040 px x 20 ns = 20.8 us)
        #45_000;
        $finish;
    end

endmodule
