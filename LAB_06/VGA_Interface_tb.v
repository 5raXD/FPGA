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

    // 800x600@72 timing (mirror of the DUT localparams)
    localparam H_VISIBLE = 799, H_FRONT_PORCH = 855, H_SYNC_END = 975, H_TOTAL = 1039;
    localparam V_VISIBLE = 599, V_FRONT_PORCH = 636, V_SYNC_END = 642, V_TOTAL = 665;

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

    // XCoord/YCoord are live, but Hsync/Vsync/vga* are registered one pixel later,
    // so delay the coords by one pixel clock to line the reference up with them.
    reg [10:0] x_d, y_d;
    always @(posedge clk) if (vga_if.pix_en) begin
        x_d <= XCoord;
        y_d <= YCoord;
    end

    wire       exp_visible = (x_d <= H_VISIBLE) && (y_d <= V_VISIBLE);
    wire       exp_hsync   = (x_d > H_FRONT_PORCH) && (x_d <= H_SYNC_END);
    wire       exp_vsync   = (y_d > V_FRONT_PORCH) && (y_d <= V_SYNC_END);
    wire [3:0] exp_red     = exp_visible ? pixel_color[11:8] : 4'h0;
    wire [3:0] exp_green   = exp_visible ? pixel_color[7:4]  : 4'h0;
    wire [3:0] exp_blue    = exp_visible ? pixel_color[3:0]  : 4'h0;

    reg checking;
    always @(negedge clk) if (checking) begin
        if (XCoord > H_TOTAL || YCoord > V_TOTAL) begin
            correct = 1'b0;
            $display("[%0t] FAIL coord out of range: X=%0d Y=%0d", $time, XCoord, YCoord);
        end
        if (Hsync !== exp_hsync) begin
            correct = 1'b0;
            $display("[%0t] FAIL Hsync=%b exp=%b at x=%0d", $time, Hsync, exp_hsync, x_d);
        end
        if (Vsync !== exp_vsync) begin
            correct = 1'b0;
            $display("[%0t] FAIL Vsync=%b exp=%b at y=%0d", $time, Vsync, exp_vsync, y_d);
        end
        if ({vgaRed,vgaGreen,vgaBlue} !== {exp_red,exp_green,exp_blue}) begin
            correct = 1'b0;
            $display("[%0t] FAIL color=%h exp=%h vis=%b", $time,
                     {vgaRed,vgaGreen,vgaBlue}, {exp_red,exp_green,exp_blue}, exp_visible);
        end
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("VGA_Interface_tb.vcd");
            $dumpvars(0, VGA_Interface_tb);
        end

        // Initialize Inputs
        clk         = 0;
        rstn        = 1;
        correct     = 1'b1;
        checking    = 1'b0;
        pixel_color = 12'hAF3;

        // active-low reset
        #10 rstn = 0;
        #50 rstn = 1;

        // let the 1-pixel pipeline fill, then start self-checking
        repeat (4) @(negedge clk);
        checking = 1'b1;

        // run a bit over one full frame (1040 x 666 x 20 ns = 13.85 ms)
        #15_000_000;

        checking = 1'b0;
        if (correct) $display("Test Passed - %m");
        else         $display("Test Failed - %m");
        $finish;
    end

endmodule
