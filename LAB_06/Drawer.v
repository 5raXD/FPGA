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
// Dependencies:    Debouncer (from LAB_04)
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

    // 800x600 visible region downsampled by 8
    localparam integer GRID_W = 100;
    localparam integer GRID_H = 75;
    localparam integer CX     = GRID_W / 2; // 50
    localparam integer CY     = GRID_H / 2; // 37

    // 20-bit debouncer
    wire btnu_pulse, btnd_pulse, btnl_pulse, btnr_pulse;
    Debouncer #(.COUNTER_BITS(20)) db_u (.clk(clk), .input_unstable(btnu), .output_stable(btnu_pulse));
    Debouncer #(.COUNTER_BITS(20)) db_d (.clk(clk), .input_unstable(btnd), .output_stable(btnd_pulse));
    Debouncer #(.COUNTER_BITS(20)) db_l (.clk(clk), .input_unstable(btnl), .output_stable(btnl_pulse));
    Debouncer #(.COUNTER_BITS(20)) db_r (.clk(clk), .input_unstable(btnr), .output_stable(btnr_pulse));

    // Rectangle edges in coarse-grid units (inclusive)
    reg [7:0] top, bottom, left, right;

    always @(posedge clk) begin
        if (reset) begin
            top    <= CY;
            bottom <= CY;
            left   <= CX;
            right  <= CX;
        end else begin
            if (btnu_pulse && top    >  0           ) top    <= top    - 1'b1;
            if (btnd_pulse && bottom <  GRID_H - 1  ) bottom <= bottom + 1'b1;
            if (btnl_pulse && left   >  0           ) left   <= left   - 1'b1;
            if (btnr_pulse && right  <  GRID_W - 1  ) right  <= right  + 1'b1;
        end
    end

    // Coarse-grid coordinate
    wire [7:0] x_ds = XCoord[10:3];
    wire [7:0] y_ds = YCoord[10:3];

    wire inside = (x_ds >= left) && (x_ds <= right)
               && (y_ds >= top ) && (y_ds <= bottom);

    always @(posedge clk) begin
        pixel_color <= inside ? sw : 12'h000;
    end

endmodule
