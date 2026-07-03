`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Font_ROM
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Tiny 8x8 pixel font, combinational LUT-ROM.
//                  Only the glyphs the HUD needs: digits 0-9 and the
//                  letters of "P1/P2/WINS/DRAW". Each glyph is one 64-bit
//                  constant, rows top->bottom, bit 7 = leftmost pixel.
//////////////////////////////////////////////////////////////////////////////////

module Font_ROM(
    input  wire [4:0] ch,     // character code (see localparams)
    input  wire [2:0] row,    // glyph row 0 (top) .. 7 (bottom)
    output wire [7:0] bits    // 8 pixels, bit 7 = leftmost
    );

    // character codes (digits are their own value)
    localparam CH_P  = 5'd10;
    localparam CH_W  = 5'd11;
    localparam CH_I  = 5'd12;
    localparam CH_N  = 5'd13;
    localparam CH_S  = 5'd14;
    localparam CH_D  = 5'd15;
    localparam CH_R  = 5'd16;
    localparam CH_A  = 5'd17;
    localparam CH_SP = 5'd18; // space (and any undefined code)
    localparam CH_L  = 5'd19;
    localparam CH_Y  = 5'd20;
    localparam CH_E  = 5'd21;

    reg [63:0] glyph;
    always @(*) begin
        case (ch)
            5'd0:  glyph = 64'h3C66666666663C00; // 0
            5'd1:  glyph = 64'h1838181818183C00; // 1
            5'd2:  glyph = 64'h3C66060C18307E00; // 2
            5'd3:  glyph = 64'h3C66061C06663C00; // 3
            5'd4:  glyph = 64'h0C1C2C4C7E0C0C00; // 4
            5'd5:  glyph = 64'h7E607C0606663C00; // 5
            5'd6:  glyph = 64'h3C66607C66663C00; // 6
            5'd7:  glyph = 64'h7E060C1830303000; // 7
            5'd8:  glyph = 64'h3C66663C66663C00; // 8
            5'd9:  glyph = 64'h3C66663E06663C00; // 9
            CH_P:  glyph = 64'h7C66667C60606000; // P
            CH_W:  glyph = 64'h6363636B7F776300; // W
            CH_I:  glyph = 64'h3C18181818183C00; // I
            CH_N:  glyph = 64'h66767E7E6E666600; // N
            CH_S:  glyph = 64'h3C66603C06663C00; // S
            CH_D:  glyph = 64'h7C66666666667C00; // D
            CH_R:  glyph = 64'h7C66667C6C666600; // R
            CH_A:  glyph = 64'h183C66667E666600; // A
            CH_L:  glyph = 64'h6060606060607E00; // L
            CH_Y:  glyph = 64'h6666663C18181800; // Y
            CH_E:  glyph = 64'h7E60607C60607E00; // E
            default: glyph = 64'h0;              // space
        endcase
    end

    // row 0 lives in bits [63:56]
    assign bits = glyph[{3'd7 - row, 3'b000} +: 8];

endmodule
