`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Pixel_Painter
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Render hub: converts the VGA pixel counters to grid
//                  coordinates (8x8 px blocks), owns the GridMapper (screen
//                  FSM + colors) and the Hud (score text + winner text) and
//                  composes the final pixel:
//                      HUD text > grid lines > block color
//////////////////////////////////////////////////////////////////////////////////

module Pixel_Painter #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire start_press,              // menu confirm (leaves welcome screen)
    input  wire key_any,                  // any key/button (leaves game over)
    input  wire sel_2p,                   // menu cursor
    input  wire mode_2p,                  // latched game mode
    input  wire crash,                    // either player crashed
    input  wire is_food,
    input  wire is_bonus,
    input  wire on_snake1,
    input  wire is_head1,
    input  wire on_snake2,
    input  wire is_head2,
    input  wire [1:0] winner,             // 00 draw, 01 P1, 10 P2
    input  wire [3:0] p1_tens, p1_ones,   // BCD scores for the HUD
    input  wire [3:0] p2_tens, p2_ones,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    // Outputs
    output wire [$clog2(GRID_X)-1:0] x,
    output wire [$clog2(GRID_Y)-1:0] y,
    output wire game_idle,
    output wire game_over,
    output wire [11:0] pixel_color
    );

    wire on_grid;
    wire grid_enable;
    wire [11:0] block_color;
    wire [$clog2(2*GRID_X)-1:0] img_x;
    wire [$clog2(2*GRID_Y)-1:0] img_y;
    wire hud_on;
    wire [11:0] hud_color;

    GridMapper #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) grid_mapper(
        // Inputs
        .clk(clk),
        .reset(reset),
        .start(start_press),
        .key_any(key_any),
        .crash(crash),
        .is_food(is_food),
        .is_bonus(is_bonus),
        .on_snake1(on_snake1),
        .is_head1(is_head1),
        .on_snake2(on_snake2),
        .is_head2(is_head2),
        .x(x),             // grid cell : checkerboard background
        .y(y),
        .img_x(img_x),     // pixel>>2 : 200x150 screen bitmaps
        .img_y(img_y),
        // Outputs
        .grid_enable(grid_enable),
        .in_idle(game_idle),
        .in_over(game_over),
        .block_color(block_color)
    );

    Hud hud(
        // Inputs
        .clk(clk),
        .XCoord(XCoord),
        .YCoord(YCoord),
        .show_menu(game_idle),             // 1P/2P picker on the welcome screen
        .sel_2p(sel_2p),
        .two_p(mode_2p),
        .show_scores(~game_idle),          // PLAY and GAME_OVER
        .show_winner(game_over & mode_2p), // no winner text in single player
        .winner(winner),
        .p1_tens(p1_tens),
        .p1_ones(p1_ones),
        .p2_tens(p2_tens),
        .p2_ones(p2_ones),
        // Outputs
        .hud_on(hud_on),
        .hud_color(hud_color)
    );

    // grid lines - mask - pixel level
    assign on_grid = (XCoord[2:0] == 3'b000) || (YCoord[2:0] == 3'b000); // 8x8 grid
    assign pixel_color = hud_on                  ? hud_color :
                         (grid_enable & on_grid) ? 12'h000   :
                                                   block_color;
    assign x = XCoord >> 3;
    assign y = YCoord >> 3;
    assign img_x = XCoord >> 2;
    assign img_y = YCoord >> 2;

    // pixels with XCoord > 800 or YCoord > 600 are blanked by VGA_Interface,
    // so we don't need to handle them here
endmodule
