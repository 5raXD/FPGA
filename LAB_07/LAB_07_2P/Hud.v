`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (1/2 players)
// Module Name:     Hud
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     On-screen text overlay, rendered from Font_ROM:
//
//                  1. Mode menu (IDLE only) - an opaque box over the welcome
//                     art, glyphs scaled x2:
//                         "1 PLAYER"     Y 384..399
//                         "2 PLAYERS"    Y 416..431
//                     The selected line is bright white, the other dim.
//
//                  2. Score line (PLAY + GAME_OVER), top 16 px, scaled x2:
//                         "P1 nn"  left,  in P1's yellow
//                         "P2 nn"  right, in P2's cyan (2-player mode only)
//
//                  3. Winner line (GAME_OVER, 2-player mode only), scaled x4
//                     at Y 544..575 - an empty band of the skull bitmap:
//                         " P1 WINS" / " P2 WINS" / "  DRAW  "
//
//                  Output is registered (1 clk = half a 50 MHz pixel, same
//                  latency as every other answer on the pixel path).
//////////////////////////////////////////////////////////////////////////////////

module Hud(
    // Inputs
    input  wire clk,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    input  wire show_menu,            // IDLE: draw the 1P/2P picker
    input  wire sel_2p,               // menu cursor: 0 = 1 PLAYER, 1 = 2 PLAYERS
    input  wire two_p,                // latched game mode (hides P2 score in 1P)
    input  wire show_scores,          // PLAY or GAME_OVER
    input  wire show_winner,          // GAME_OVER in 2-player mode
    input  wire [1:0] winner,         // 00 draw, 01 P1 wins, 10 P2 wins
    input  wire [3:0] p1_tens, p1_ones,
    input  wire [3:0] p2_tens, p2_ones,
    // Outputs
    output reg hud_on,
    output reg [11:0] hud_color
    );

    localparam P1_COLOR   = 12'hFD0;  // P1 head yellow
    localparam P2_COLOR   = 12'h0EF;  // P2 head cyan
    localparam DRAW_COLOR = 12'hFFF;
    localparam MENU_SEL   = 12'hFFF;  // selected menu line
    localparam MENU_DIM   = 12'h353;  // unselected menu line
    localparam MENU_BG    = 12'h021;  // menu box - same as the welcome art bg

    // character codes (must match Font_ROM)
    localparam CH_P  = 5'd10;
    localparam CH_W  = 5'd11;
    localparam CH_I  = 5'd12;
    localparam CH_N  = 5'd13;
    localparam CH_S  = 5'd14;
    localparam CH_D  = 5'd15;
    localparam CH_R  = 5'd16;
    localparam CH_A  = 5'd17;
    localparam CH_SP = 5'd18;
    localparam CH_L  = 5'd19;
    localparam CH_Y  = 5'd20;
    localparam CH_E  = 5'd21;

    // ---------------- score line: Y 0..15, 16 px per char ----------------
    wire in_score_band = show_scores && (YCoord < 16);
    wire [6:0] s_col = XCoord[10:4];      // character column 0..49
    wire s_is_p2 = (s_col >= 7'd44);
    // "P1 nn" at columns 1-5, "P2 nn" at columns 44-48 (2P mode only)
    reg [4:0] s_ch;
    always @(*) begin
        case (s_col)
            7'd1:  s_ch = CH_P;
            7'd2:  s_ch = 5'd1;
            7'd4:  s_ch = {1'b0, p1_tens};
            7'd5:  s_ch = {1'b0, p1_ones};
            7'd44: s_ch = CH_P;
            7'd45: s_ch = 5'd2;
            7'd47: s_ch = {1'b0, p2_tens};
            7'd48: s_ch = {1'b0, p2_ones};
            default: s_ch = CH_SP;
        endcase
        if (s_is_p2 && !two_p)            // single player: no P2 score
            s_ch = CH_SP;
    end

    // ---------------- mode menu (IDLE): opaque box, two x2 lines ---------
    // box: X 320..479, Y 376..439. Text starts at X 328; the line Y starts
    // are multiples of 16, so YCoord[3:1] is the glyph row directly.
    wire in_menu_box = show_menu
                    && (XCoord >= 11'd320) && (XCoord < 11'd480)
                    && (YCoord >= 11'd376) && (YCoord < 11'd440);
    wire [10:0] mx = XCoord - 11'd328;    // text-relative X (valid in the box)
    wire [3:0] m_col = mx[7:4];           // character column 0..8
    wire in_menu1 = in_menu_box && (YCoord >= 11'd384) && (YCoord < 11'd400)
                 && !mx[10] && (mx < 11'd128);   // "1 PLAYER"  - 8 chars
    wire in_menu2 = in_menu_box && (YCoord >= 11'd416) && (YCoord < 11'd432)
                 && !mx[10] && (mx < 11'd144);   // "2 PLAYERS" - 9 chars
    reg [4:0] m_ch;
    always @(*) begin
        case (m_col)
            4'd0:  m_ch = in_menu2 ? 5'd2 : 5'd1;
            4'd2:  m_ch = CH_P;
            4'd3:  m_ch = CH_L;
            4'd4:  m_ch = CH_A;
            4'd5:  m_ch = CH_Y;
            4'd6:  m_ch = CH_E;
            4'd7:  m_ch = CH_R;
            4'd8:  m_ch = CH_S;              // only reachable on line 2
            default: m_ch = CH_SP;
        endcase
    end
    wire menu_line_sel = (in_menu1 && !sel_2p) || (in_menu2 && sel_2p);

    // ---------------- winner line: Y 544..575, X 272..527, 32 px per char
    wire in_win_band = show_winner
                    && (YCoord >= 11'd544) && (YCoord <= 11'd575)
                    && (XCoord >= 11'd272) && (XCoord <= 11'd527);
    wire [10:0] wx = XCoord - 11'd272;    // 0..255 inside the band
    wire [2:0] w_col = wx[7:5];           // character column 0..7
    // 8-char message: " P1 WINS" / " P2 WINS" / "  DRAW  "
    reg [4:0] w_ch;
    always @(*) begin
        if (winner == 2'b00) begin        // draw
            case (w_col)
                3'd2: w_ch = CH_D;
                3'd3: w_ch = CH_R;
                3'd4: w_ch = CH_A;
                3'd5: w_ch = CH_W;
                default: w_ch = CH_SP;
            endcase
        end else begin
            case (w_col)
                3'd1: w_ch = CH_P;
                3'd2: w_ch = (winner == 2'b01) ? 5'd1 : 5'd2;
                3'd4: w_ch = CH_W;
                3'd5: w_ch = CH_I;
                3'd6: w_ch = CH_N;
                3'd7: w_ch = CH_S;
                default: w_ch = CH_SP;
            endcase
        end
    end

    // ---------------- shared font lookup (regions are disjoint) ----------
    wire in_menu_text = in_menu1 || in_menu2;
    wire [4:0] ch  = in_win_band  ? w_ch :
                     in_menu_text ? m_ch : s_ch;
    wire [2:0] row = in_win_band  ? YCoord[4:2] : YCoord[3:1]; // /4 vs /2
    wire [2:0] col = in_win_band  ? wx[4:2] :
                     in_menu_text ? mx[3:1] : XCoord[3:1];

    wire [7:0] font_bits;
    Font_ROM font_rom(.ch(ch), .row(row), .bits(font_bits));

    wire pix = font_bits[3'd7 - col];

    wire [11:0] color_c = in_win_band  ? ((winner == 2'b01) ? P1_COLOR :
                                          (winner == 2'b10) ? P2_COLOR : DRAW_COLOR) :
                          in_menu_text ? (menu_line_sel ? MENU_SEL : MENU_DIM) :
                                         (s_is_p2 ? P2_COLOR : P1_COLOR);

    always @(posedge clk) begin
        // the menu box is opaque: it claims every pixel inside it (text and
        // background); everything else only claims actual glyph pixels
        hud_on    <= in_menu_box ||
                     ((in_score_band || in_win_band) && pix);
        hud_color <= (in_menu_box && !(in_menu_text && pix)) ? MENU_BG : color_c;
    end

endmodule
