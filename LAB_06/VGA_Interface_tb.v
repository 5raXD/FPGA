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

    reg [11:0] expected_pixel_color;
    reg [10:0] x_d, y_d;



    always @(posedge clk) begin
        expected_pixel_color <= pixel_color;
        x_d <= XCoord;
        y_d <= YCoord;

        if(vga_if.pix_en == 1) begin
            pixel_color <= (XCoord <= H_VISIBLE && YCoord <= V_VISIBLE)? $random : 12'h000;
            correct <= ({vgaRed, vgaGreen, vgaBlue} === ((x_d <= H_VISIBLE && y_d <= V_VISIBLE) ? expected_pixel_color : 12'h000)) &&
                    (Hsync === ((x_d > H_FRONT_PORCH) && (x_d <= H_SYNC_END))) &&
                    (Vsync === ((y_d > V_FRONT_PORCH) && (y_d <= V_SYNC_END))) &&
                    correct;
        end
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("VGA_Interface_tb.vcd");
            $dumpvars(0, VGA_Interface_tb);
        end

        clk = 0;
        correct = 1;
        rstn = 1;
        pixel_color = 12'h000;
        expected_pixel_color = 12'h000;
        x_d = 0;
        y_d = 0;

        // reset
        @(posedge clk); 
        rstn = 0;
        correct = 1;
        #10;
        rstn = 1;
        correct = 1;

        repeat ((H_TOTAL+1) * (V_TOTAL+1) * 2) #10; // run for 1 frames

        if (correct) begin
            $display("Test passed!");
        end else begin
            $display("Test failed!");
        end
        $finish;
    end

endmodule
