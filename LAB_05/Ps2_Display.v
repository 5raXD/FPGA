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
    reg [6:0] a_to_g;
    reg [3:0] an_reg;
    reg       dp_reg;
    
    assign seg = a_to_g;
    assign an  = an_reg;
    assign dp  = dp_reg;
    
    wire [1:0] s;    
    reg  [3:0] digit;

    reg kp_sync1, kp_sync2, kp_prev;
    reg [7:0] valid_scancode;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            kp_sync1 <= 1'b0;
            kp_sync2 <= 1'b0;
            kp_prev  <= 1'b0;
            valid_scancode <= 8'h00;
        end else begin
            kp_sync1 <= keyPressed;
            kp_sync2 <= kp_sync1;
            kp_prev  <= kp_sync2;
            
            if ((kp_sync2 & ~kp_prev) && scancode != 8'hE0) begin
                valid_scancode <= scancode;
            end
        end
    end
    
    wire kp_edge = kp_sync2 & ~kp_prev;

    reg [23:0] led_timer;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            led_timer <= 24'd0;
            led <= 1'b0;
        end else if (kp_edge && scancode != 8'hE0) begin
            led_timer <= 24'd10_000_000; // ~0.1 seconds at 100MHz
            led <= 1'b1;
        end else if (led_timer > 0) begin
            led_timer <= led_timer - 1;
            led <= 1'b1;
        end else begin
            led <= 1'b0;
        end
    end

    reg [19:0] clkdiv = 20'b0;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            clkdiv <= 0;
        else
            clkdiv <= clkdiv + 1;
    end
    
    assign s = clkdiv[19:18];

    always @(*) begin
        an_reg = 4'b1111; 
        
        case(s)
            2'b00: begin 
                digit = valid_scancode[3:0];
                an_reg[0] = 1'b0;  // Turn on rightmost
            end
            2'b01: begin 
                digit = valid_scancode[7:4];
                an_reg[1] = 1'b0;  // Turn on 2nd right
            end
            default: begin 
                digit = 4'h0; 
                an_reg = 4'b1111;
            end
        endcase
    end

    always @(*) begin
        dp_reg = 1'b1; // dp off by default (active-low)
        case(digit)
            //////////<---MSB-LSB<---/////
            //////////////gfedcba/////////
            4'h0: a_to_g = 7'b1000000; // 0
            4'h1: a_to_g = 7'b1111001; // 1
            4'h2: a_to_g = 7'b0100100; // 2
            4'h3: a_to_g = 7'b0110000; // 3
            4'h4: a_to_g = 7'b0011001; // 4
            4'h5: a_to_g = 7'b0010010; // 5
            4'h6: a_to_g = 7'b0000010; // 6
            4'h7: a_to_g = 7'b1111000; // 7
            4'h8: a_to_g = 7'b0000000; // 8
            4'h9: a_to_g = 7'b0010000; // 9
            4'hA: a_to_g = 7'b0001000; // A
            4'hB: a_to_g = 7'b0000011; // lowercase b
            4'hC: a_to_g = 7'b1000110; // C
            4'hD: a_to_g = 7'b0100001; // lowercase d
            4'hE: a_to_g = 7'b0000110; // E
            4'hF: a_to_g = 7'b0001110; // F
            default: a_to_g = 7'b1111111; // blank
        endcase
    end


endmodule
