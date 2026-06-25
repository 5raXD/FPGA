`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module Renderer( // delete me
    // Inputs
    input  wire        clk,
    input  wire        reset,
    // input  wire [1:0]  dir,
    input  wire [10:0] XCoord,
    input  wire [10:0] YCoord,
    // Outputs
    output reg  [11:0] pixel_color
);

    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    reg [1:0] state = IDLE;
    

    // snake location - block level


    // farmer - food allocation - block level
    //      food generator


    // pixel color assignment - case for display layers (background, grid, snake, food)


    // 




endmodule