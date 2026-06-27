`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module Pixel_Painter #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire tick,
    input wire keyPressed,
    // input  wire [1:0]  dir,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    // Outputs
    output reg  [11:0] pixel_color
    );

    wire on_grid;
    wire grid_enable;
    wire [$clog2(GRID_X)-1:0] x = XCoord >> 3; // divide by 8
    wire [$clog2(GRID_Y)-1:0] y = YCoord >> 3; // divide by 8
    wire [11:0] block_color;

    GridMapper #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) grid_mapper(
    // Inputs
    .clk(clk),
    .reset(reset),
    .keyPressed(keyPressed),
    .x(x),
    .y(y),
    // Outputs
    .grid_enable(grid_enable),
    .block_color(block_color)
    );

    // grid lines - mask - pixel level
    assign on_grid = (XCoord[2:0] == 3'b000) || (YCoord[2:0] == 3'b000); // 8x8 grid
    assign pixel_color = (grid_enable & on_grid)? 12'h000 : block_color;

    // who's responsible for the pixels XCoord > 800 or YCoord > 600?
    // it the inteface as i expected so we dont need to hanke that here
endmodule