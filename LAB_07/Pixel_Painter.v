`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module Pixel_Painter #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire tick,        // unused for now - reserved for animations
    input wire keyPressed,
    input wire crash,
    input wire is_food,
    input wire on_snake,
    input wire is_head,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    // Outputs
    output wire [$clog2(GRID_X)-1:0] x,
    output wire [$clog2(GRID_Y)-1:0] y,
    output wire game_idle,
    output wire  [11:0] pixel_color
    );

    wire on_grid;
    wire grid_enable;
    wire [11:0] block_color;
    wire [$clog2(2*GRID_X)-1:0] img_x;
    wire [$clog2(2*GRID_Y)-1:0] img_y;

    GridMapper #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) grid_mapper(
    // Inputs
    .clk(clk),
    .reset(reset),
    .keyPressed(keyPressed),
    .crash(crash),
    .is_food(is_food),
    .on_snake(on_snake),
    .is_head(is_head),
    .x(x),             // grid cell : checkerboard background
    .y(y),
    .img_x(img_x),     // pixel>>2 : 200x150 screen bitmaps
    .img_y(img_y),
    // Outputs
    .grid_enable(grid_enable),
    .in_idle(game_idle),
    .block_color(block_color)
    );

    // grid lines - mask - pixel level
    assign on_grid = (XCoord[2:0] == 3'b000) || (YCoord[2:0] == 3'b000); // 8x8 grid
    assign pixel_color = (grid_enable & on_grid)? 12'h000 : block_color;
    assign x = XCoord >> 3;
    assign y = YCoord >> 3;
    assign img_x = XCoord >> 2;
    assign img_y = YCoord >> 2;

    // pixels with XCoord > 800 or YCoord > 600 are blanked by VGA_Interface,
    // so we don't need to handle them here
endmodule
