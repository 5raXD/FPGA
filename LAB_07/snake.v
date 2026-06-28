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

    // next head position (combinational) from current head + direction
    reg [$clog2(GRID_X)-1:0] next_x;
    reg [$clog2(GRID_Y)-1:0] next_y;
    always @(*) begin
        next_x = head_x;
        next_y = head_y;
        case(dir)
            UP:    next_y = head_y - 1;
            DOWN:  next_y = head_y + 1;
            LEFT:  next_x = head_x - 1;
            RIGHT: next_x = head_x + 1;
        endcase
    end

    wire is_eaten = (next_x == plant_x) && (next_y == plant_y);
    wire hit_wall = (next_x >= GRID_X) || (next_y >= GRID_Y);
    wire hit_self = (grid[next_y][next_x] != 0);

    integer i, j;
    always @(posedge clk) begin
        if(reset) begin
            length <= 1;
            head_x <= GRID_X >> 1;
            head_y <= GRID_Y >> 1;
            crash  <= 0;
            // clear the board - otherwise cells read as 'x' and crash fires
            for(i = 0; i < GRID_Y; i = i + 1)
                for(j = 0; j < GRID_X; j = j + 1)
                    grid[i][j] <= 0;
            grid[GRID_Y >> 1][GRID_X >> 1] <= 1; // stamp the starting head
        end else if(tick && !crash) begin
            // crash on wall or own body, checked on the NEW head cell
            if(hit_wall || hit_self) begin
                crash <= 1;
            end else begin
                head_x <= next_x;
                head_y <= next_y;
                if(is_eaten) begin
                    // ate food: keep the tail (no decrement), grow, head = new length
                    length <= length + 1;
                    grid[next_y][next_x] <= length + 1;
                end else begin
                    // normal move: write head = length, then tick every cell down
                    grid[next_y][next_x] <= length;
                    for(i = 0; i < GRID_Y; i = i + 1)
                        for(j = 0; j < GRID_X; j = j + 1)
                            if(grid[i][j] != 0)
                                grid[i][j] <= grid[i][j] - 1;
                end
            end
        end
    end

    // farmer - food allocation - block level
    always @(posedge clk) begin
        if((is_eaten && tick) || reset) begin // relocate food on eat (or at start)
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
    assign is_head  = (grid[y][x] != 0) && (grid[y][x] == length);
    assign is_food  = (x == plant_x) && (y == plant_y);
    assign score    = length;

endmodule