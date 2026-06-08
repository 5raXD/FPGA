`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Display
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Visual feedback for the PS/2 interface, running on the fast
//                  100 MHz system clock:
//                    * shows the two hex symbols of "scancode" on the two
//                      right-hand 7-segment digits (left two blank), latching the
//                      value until the next key press;
//                    * blinks "led" with one short, eye-visible strobe per press.
//
//                  Clock-Domain Crossing: scancode/keyPressed are produced in the
//                  slow PS2Clk domain. keyPressed is passed through a 3-FF
//                  synchroniser and edge-detected; scancode is sampled into this
//                  domain on that (already settled) pulse - a simple, safe data +
//                  valid CDC handshake.
//
// Dependencies:    Seg_7_Display
//
// Revision:        1.0
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Display(
    input  wire       clk,         // 100 MHz system clock
    input  wire       rstn,        // active-low reset
    input  wire       keyPressed,  // pulse from Ps2_Interface (slow domain)
    input  wire [7:0] scancode,    // byte from Ps2_Interface (slow domain)
    output wire [6:0] seg,         // 7-segment cathodes (active low)
    output wire [3:0] an,          // 4 digit anodes (active low)
    output wire       dp,          // decimal point
    output reg        led          // strobe LED, one visible blink per press
    );

    // ~84 ms blink at 100 MHz (2^23 / 100e6).  Visible but short.
    localparam STROBE_BITS = 23;

    // ---- CDC: synchronise keyPressed into the clk domain and edge-detect it ----
    reg kp_s1, kp_s2, kp_s3;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            kp_s1 <= 1'b0; kp_s2 <= 1'b0; kp_s3 <= 1'b0;
        end
        else begin
            kp_s1 <= keyPressed;
            kp_s2 <= kp_s1;
            kp_s3 <= kp_s2;
        end
    end
    wire kp_rise = kp_s2 & ~kp_s3;          // one clk-cycle pulse per key press

    // ---- CDC: 2-FF the data bus, then capture it on the (settled) pulse ----
    reg [7:0] sc_s1, sc_s2, scancode_disp;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sc_s1 <= 8'd0; sc_s2 <= 8'd0; scancode_disp <= 8'd0;
        end
        else begin
            sc_s1 <= scancode;
            sc_s2 <= sc_s1;
            if (kp_rise) scancode_disp <= sc_s2;   // latch until next press
        end
    end

    // ---- LED strobe: load a down-counter on each press, hold led while it runs --
    reg [STROBE_BITS-1:0] strobe_cnt;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            strobe_cnt <= 0;
            led        <= 1'b0;
        end
        else if (kp_rise) begin
            strobe_cnt <= {STROBE_BITS{1'b1}};
            led        <= 1'b1;
        end
        else if (strobe_cnt != 0) begin
            strobe_cnt <= strobe_cnt - 1'b1;
            led        <= 1'b1;
        end
        else begin
            led <= 1'b0;
        end
    end

    // ---- 7-segment: scancode on the two RIGHT digits, two LEFT digits blank ----
    Seg_7_Display seg7(
        .x      ({8'h00, scancode_disp}),
        .clk    (clk),
        .clr    (~rstn),
        .blank  (4'b1100),          // blank digits 3 and 2 (the two left ones)
        .a_to_g (seg),
        .an     (an),
        .dp     (dp)
    );

endmodule
