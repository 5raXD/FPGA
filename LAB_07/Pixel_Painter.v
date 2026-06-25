`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module Pixel_Painter(
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

    GridMapper #(.GRID_X(100), .GRID_Y(75)) grid_mapper(
    // Inputs
    .clk(clk),
    .reset(reset),
    .keyPressed(keyPressed),
    // Outputs
    .grid_enable(grid_enable),
    .block_color(pixel_color)
    );


    


    // grid lines - mask - pixel level



endmodule