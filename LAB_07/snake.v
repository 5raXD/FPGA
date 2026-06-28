`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Snake #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input wire clk,
    input wire reset,
    input wire tick,
    input wire [1:0] dir,
    input wire keyPressed,
    // Inputs - (x,y) from pixel_painter - Query: is this pixel on the snake? 
    input wire [$clog2(GRID_X)-1:0] x,
    input wire [$clog2(GRID_Y)-1:0] y,
    // Inputs - food location (from farmer)
    // input wire plant_food,
    // input wire [$clog2(GRID_X)-1:0] food_x,
    // input wire [$clog2(GRID_Y)-1:0] food_y,
    // // Inputs - pixel being scanned (read address from the renderer)
    // input wire [10:0] XCoord,
    // input wire [10:0] YCoord,
    // Outputs
    // Outputs - grid reads (to Pixel_Painter / GridMapper)
    output wire on_snake, // Query: is this snake block?
    output wire is_head, // Query: is this block the head of the snake?
    // Outputs - food cell occupancy (to farmer, so food avoids the body)
    output wire is_food, // Query: is this food block?
    // Outputs - game status
    output reg crash,
    output wire [15:0] score
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    // Snake data
    // the grid - one value per block: 0 = empty, n = clears in n more ticks
    reg [$clog2(GRID_X*GRID_Y)-1:0] grid [0:GRID_Y-1][0:GRID_X-1];
    reg [$clog2(GRID_X*GRID_Y)-1:0] length;
    // head position - block level
    reg [$clog2(GRID_X)-1:0] head_x;
    reg [$clog2(GRID_Y)-1:0] head_y;

    // Plant position - block level
    wire [$clog2(GRID_X)-1:0] famer_plant_x;
    wire [$clog2(GRID_Y)-1:0] famer_plant_y; 
    reg [$clog2(GRID_X)-1:0] plant_x;
    reg [$clog2(GRID_Y)-1:0] plant_y;

    wire is_eaten;

    always @(posedge clk) begin
        if(reset) begin
            length <= 1;
            head_x <= GRID_X >>1;
            head_y <= GRID_Y >>1;
            crash <= 0;
        end else if(tick && !crash) begin
            // move the snake in the current direction
            case(dir)
                UP:    head_y <= head_y - 1;
                DOWN:  head_y <= head_y + 1;
                LEFT:  head_x <= head_x - 1;
                RIGHT: head_x <= head_x + 1;
            endcase

            // check for crash with walls or self
            if(head_x >= GRID_X || head_y >= GRID_Y || grid[head_y][head_x] != 0) begin
                crash <= 1;
            end else begin
                // check if food is eaten
                length <= is_eaten? length + 1 : length;
                // update the grid with the new head position
                grid[head_y][head_x] <= length;

                // decrement all non-zero cells in the grid
                for(int i = 0; i < GRID_Y; i++) begin
                    for(int j = 0; j < GRID_X; j++) begin
                        if((grid[i][j] > 0) && (i != head_y && j != head_x && is_eaten)) begin
                            grid[i][j] <= grid[i][j] - 1;
                        end
                    end
                end
            end

        end
    end



    // farmer - food allocation - block level
    always @(posedge clk) begin
        if((is_eaten && tick) || reset) begin // if not on the snake & not eating food
            plant_x <= famer_plant_x;
            plant_y <= famer_plant_y;
        end
    end
    // food generator
    farmer #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) farmer(
        // Inputs
        .clk(clk),
        .keyPressed(keyPressed),
        // Outputs
        .food_x(famer_plant_x),
        .food_y(famer_plant_y)
    );


    // read ports - combinational, anyone reads by giving an address
    assign on_snake = (grid[y][x] != 0);
    assign is_head =  (grid[y][x] != 0) && (grid[y][x] == length);
    assign score = length[15:0];
    assign is_eaten = (head_x == plant_x) && (head_y == plant_y);

endmodule