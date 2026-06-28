`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Snake #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input wire clk,
    input wire reset,
    input wire tick,
    input wire [1:0] dir,
    // Inputs - food location (from farmer)
    input wire [$clog2(GRID_X)-1:0] food_x,
    input wire [$clog2(GRID_Y)-1:0] food_y,
    // Inputs - pixel being scanned (read address from the renderer)
    input wire [10:0] XCoord,
    input wire [10:0] YCoord,
    // Outputs
    // Outputs - grid reads (to Pixel_Painter / GridMapper)
    output wire on_snake,
    output wire is_head,
    // Outputs - food cell occupancy (to farmer, so food avoids the body)
    output wire food_on_snake,
    // Outputs - game status
    output reg crash,
    output reg [15:0] score
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    // the grid - one value per block: 0 = empty, n = clears in n more ticks
    reg [$clog2(GRID_X*GRID_Y)-1:0] grid [0:GRID_Y-1][0:GRID_X-1];
    reg [$clog2(GRID_X*GRID_Y)-1:0] length;

    // head position - block level
    reg [$clog2(GRID_X)-1:0] head_x;
    reg [$clog2(GRID_Y)-1:0] head_y;

    // read address - the cell the renderer is scanning (divide by 8)
    wire [$clog2(GRID_X)-1:0] x = XCoord >> 3;
    wire [$clog2(GRID_Y)-1:0] y = YCoord >> 3;

    // read ports - combinational, anyone reads by giving an address
    assign on_snake = (grid[y][x] != 0);
    assign is_head = (grid[y][x] != 0) && (grid[y][x] == length);
    assign food_on_snake = (grid[food_y][food_x] != 0);

    // write port - ONLY here (single writer), advances once per tick
    // always @(posedge clk) begin
    //     if (reset) begin
    //         // init snake at center, set length, score, crash
    //     end else if (tick) begin
    //         // 1) write length into the new head cell
    //         // 2) decrement every non-zero cell (tail clears itself)
    //         // 3) ate food? bump length & score instead of shrinking
    //         // 4) crash if new head hits a wall or a non-zero cell
    //     end
    // end

endmodule