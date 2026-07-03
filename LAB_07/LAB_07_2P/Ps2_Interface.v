`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Interface
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     PS/2 keyboard interface
//
//
//////////////////////////////////////////////////////////////////////////////////

module Ps2_Interface(
    input wire PS2Clk,
    input wire rstn,
    input wire PS2Data,
    output reg [7:0] scancode,
    output reg keyPressed
    );

    reg [21:0] shift_reg = 0; // power-up values: same as the FPGA's global
    reg [3:0]  bit_count = 0; // reset, and they keep X out of downstream
    reg is_valid = 1;         // logic (the food LFSR mixes keyPressed in)
    initial begin             // before the first rstn pulse arrives
        scancode   = 0;
        keyPressed = 0;
    end
    wire parity_ok;
    wire [7:0] cur_byte  = shift_reg[20:13];
    wire [7:0] prev_byte = shift_reg[9:2];

    always @(negedge PS2Clk or negedge rstn) begin
        if (!rstn) begin
            bit_count <= 4'b0;
            shift_reg <= 22'b0;
            scancode <= 8'b0;
            keyPressed <= 1'b0;
            is_valid <= 1'b1;
        end else begin
            shift_reg <= {PS2Data, shift_reg[21:1]};
            bit_count <= (bit_count == 4'd10)? 4'd0 : bit_count + 4'd1;
            keyPressed <= 1'b0; // default

            if (bit_count == 4'd10) begin
                if (cur_byte == 8'hE0 || cur_byte == 8'hF0) begin
                    // skip
                end else if (prev_byte == 8'hF0) begin
                    is_valid <= 1'b1;
                end else begin
                    scancode <= cur_byte;
                    if (is_valid) begin
                        keyPressed <= parity_ok;
                        is_valid <= 1'b0;
                    end
                end
            end 
               
        end

    end

    assign parity_ok = (shift_reg[21] == ~(^cur_byte));

endmodule
