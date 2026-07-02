`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Saleh Khalil, Mahmood Stitia
// Module:    Pixel_Painter   (after_C_debug)
//
// Maps the scanned pixel (XCoord,YCoord) to a grid cell and asks GridMapper for
// its colour. Now forwards game_state (FSM lives at the top level). See changes.html.
//////////////////////////////////////////////////////////////////////////////////

module Pixel_Painter #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire [1:0]  game_state,
    input  wire        is_food,
    input  wire        on_snake,
    input  wire        is_head,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    // Outputs
    output wire [$clog2(GRID_X)-1:0] x,
    output wire [$clog2(GRID_Y)-1:0] y,
    output wire [11:0] pixel_color
    );

    wire on_grid;
    wire grid_enable;
    wire [11:0] block_color;

    GridMapper #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) grid_mapper(
        // Inputs
        .game_state(game_state),
        .is_food(is_food),
        .on_snake(on_snake),
        .is_head(is_head),
        .x(x),
        .y(y),
        // Outputs
        .grid_enable(grid_enable),
        .block_color(block_color)
    );

    // grid lines - mask - pixel level (8x8 grid)
    assign on_grid = (XCoord[2:0] == 3'b000) || (YCoord[2:0] == 3'b000);
    assign pixel_color = (grid_enable & on_grid) ? 12'h000 : block_color;
    assign x = XCoord >> 3;
    assign y = YCoord >> 3;

endmodule
