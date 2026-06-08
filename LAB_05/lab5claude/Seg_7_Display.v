`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Seg_7_Display
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool versions:   Vivado 2016.4
// Description:     This module translates the input vector "x" into the 
//                  appropriate signals to be fed into the 4-digit-7seg 
//                  component on the Basys3 board:
//                      a_to_g[6:0] - the 7 segments' toggles
//                      an[3:0] - the 4 common anodes of the 4 digits of the display
//                      dp - a dot toggle of every digit (kind of an 8th segment...)
//                  The digits are generated in a cyclic repetition, very fast, 
//                  such that the human eye can't see these changes and an 
//                  impression of constant 4 digits is formed.
//
// Dependencies:    None
//
// Revision:        5.0
// Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////
module Seg_7_Display(
    input  [15:0]    x,        // 4 hex nibbles, x[3:0]=rightmost digit
    input            clk,      // 100 MHz
    input            clr,      // active-high synchronous-ish clear (async on div)
    input  [3:0]     blank,    // blank[i]=1 -> digit i shows nothing
    output reg [6:0] a_to_g,   // segments, active low
    output reg [3:0] an,       // anodes, active low (one-hot-low)
    output           dp        // decimal point (kept off)
    );

    wire [1:0] s;
    reg  [3:0] digit;
    reg        digit_blank;

    // refresh divider: top two bits select the active digit (~2.6 ms / digit).
    reg [19:0] clkdiv = 20'b0;
    assign s = clkdiv[19:18];

    assign dp = 1'b1;          // lowercase b/d are used, so the dot stays off

    // pick the nibble (and its blank flag) of the currently scanned digit
    always @(posedge clk) begin
        case (s)
            2'd0: begin digit <= x[3:0];   digit_blank <= blank[0]; end
            2'd1: begin digit <= x[7:4];   digit_blank <= blank[1]; end
            2'd2: begin digit <= x[11:8];  digit_blank <= blank[2]; end
            2'd3: begin digit <= x[15:12]; digit_blank <= blank[3]; end
            default: begin digit <= x[3:0]; digit_blank <= blank[0]; end
        endcase
    end

    // hex -> 7-segment decoder (full 0..F), with lowercase b and d
    always @(*) begin
        if (digit_blank)
            a_to_g = 7'b1111111;            // all segments off
        else
            case (digit)
                //               gfedcba
                4'h0: a_to_g = 7'b1000000;  // 0
                4'h1: a_to_g = 7'b1111001;  // 1
                4'h2: a_to_g = 7'b0100100;  // 2
                4'h3: a_to_g = 7'b0110000;  // 3
                4'h4: a_to_g = 7'b0011001;  // 4
                4'h5: a_to_g = 7'b0010010;  // 5
                4'h6: a_to_g = 7'b0000010;  // 6
                4'h7: a_to_g = 7'b1111000;  // 7
                4'h8: a_to_g = 7'b0000000;  // 8
                4'h9: a_to_g = 7'b0010000;  // 9
                4'hA: a_to_g = 7'b0001000;  // A
                4'hB: a_to_g = 7'b0000011;  // b (lowercase, != 8)
                4'hC: a_to_g = 7'b1000110;  // C
                4'hD: a_to_g = 7'b0100001;  // d (lowercase, != 0)
                4'hE: a_to_g = 7'b0000110;  // E
                4'hF: a_to_g = 7'b0001110;  // F
                default: a_to_g = 7'b1111111;
            endcase
    end

    // drive exactly one anode low to light the scanned digit
    always @(*) begin
        an    = 4'b1111;
        an[s] = 1'b0;
    end

    // free-running refresh counter (async clear)
    always @(posedge clk or posedge clr) begin
        if (clr)
            clkdiv <= 20'b0;
        else
            clkdiv <= clkdiv + 1'b1;
    end

endmodule
