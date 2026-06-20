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

`define INC(x, max) ((x == max-1)? 0 : (x + 1))

module VGA_Interface(
    // Inputs
    input  wire        clk,
    input  wire        rstn,
    input  wire [11:0] pixel_color,
    // Outputs - to VGA pins
    output reg  [3:0]  vgaRed,
    output reg  [3:0]  vgaGreen,
    output reg  [3:0]  vgaBlue,
    output reg         Hsync,
    output reg         Vsync,
    // Outputs - to Drawer
    output wire  [10:0] XCoord,
    output wire  [10:0] YCoord
    );

    reg [10:0] h_count;
    reg [10:0] v_count;

    localparam H_VISIBLE = 799, H_FRONT_PORCH = 855, H_SYNC_END = 975, H_TOTAL = 1039;
    localparam V_VISIBLE = 599, V_FRONT_PORCH = 636, V_SYNC_END = 642, V_TOTAL = 665;

    // 50 MHz pixel-clock
    reg pclk = 0;
    always @(posedge clk) pclk <= ~pclk; // divide by 2 -> 50 MHz

    // wire visible = (h_count <= H_VISIBLE) && (v_count <= V_VISIBLE);


    // Display logic
    always @(posedge pclk) begin
        if (!rstn) begin
            Hsync    <= 1'b0;
            Vsync    <= 1'b0;
            vgaRed   <= 4'h0;
            vgaGreen <= 4'h0;
            vgaBlue  <= 4'h0;
        end else begin
            Hsync <= (h_count > H_FRONT_PORCH) && (h_count <= H_SYNC_END);
            Vsync <= (v_count > V_FRONT_PORCH) && (v_count <= V_SYNC_END);
            if ((h_count <= H_VISIBLE) && (v_count <= V_VISIBLE)) begin // is visible?
                vgaRed   <= pixel_color[11:8]; // Red
                vgaGreen <= pixel_color[7:4];  // Green
                vgaBlue  <= pixel_color[3:0];  // Blue
            end else begin
                vgaRed   <= 4'h0;
                vgaGreen <= 4'h0;
                vgaBlue  <= 4'h0;
            end
        end
    end


    // Coordinate counters
    always @(posedge pclk) begin
        if (!rstn) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            h_count <= `INC(h_count, H_TOTAL+1);
            if (h_count == H_TOTAL) begin
                v_count <= `INC(v_count, V_TOTAL+1);
            end
        end
    end

    // current pixel position -> Drawer
    assign XCoord = h_count;
    assign YCoord = v_count;

endmodule
