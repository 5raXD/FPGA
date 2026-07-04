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

    localparam MAX_LEN = 64;

    // Snake 
    // the body
    reg [$clog2(GRID_X)-1:0] body_x [0:MAX_LEN-1];
    reg [$clog2(GRID_Y)-1:0] body_y [0:MAX_LEN-1];
    reg [15:0] length;
    // head position
    wire [$clog2(GRID_X)-1:0] head_x = body_x[0];
    wire [$clog2(GRID_Y)-1:0] head_y = body_y[0];


    integer k;

    // next head position - block level
    reg [$clog2(GRID_X)-1:0] next_x;
    reg [$clog2(GRID_Y)-1:0] next_y;
    always @(*) begin
        next_x = head_x;
        next_y = head_y;
        // move the snake in the current direction
        case(dir)
            UP: next_y = head_y - 1;
            DOWN: next_y = head_y + 1;
            LEFT: next_x = head_x - 1;
            RIGHT: next_x = head_x + 1;
        endcase
    end

    // self-collision - does the next head land on the body?
    reg hit_self;
    always @(*) begin
        hit_self = 0;
        for(k = 0; k < MAX_LEN; k = k + 1) begin
            if((k < length) && (body_x[k] == next_x) && (body_y[k] == next_y)) begin
                hit_self = 1;
            end
        end
    end

    reg [$clog2(GRID_X)-1:0] next_x_r;
    reg [$clog2(GRID_Y)-1:0] next_y_r;
    reg hit_self_r;
    reg is_eaten_r;
    reg tick_d;
    wire is_eaten;
    always @(posedge clk) begin
        next_x_r <= next_x;
        next_y_r <= next_y;
        hit_self_r <= hit_self;
        is_eaten_r <= is_eaten;
        tick_d <= tick;
    end

    always @(posedge clk) begin
        if(reset) begin
            length <= 1;
            body_x[0] <= GRID_X >>1;
            body_y[0] <= GRID_Y >>1;
            crash <= 0;
        end else if(tick_d && !crash) begin
            // check for crash with walls or self
            if(next_x_r >= GRID_X || next_y_r >= GRID_Y || hit_self_r) begin
                crash <= 1;
            end else begin
                // advance the body - each block follows the one ahead of it
                for(k = MAX_LEN-1; k > 0; k = k - 1) begin
                    body_x[k] <= body_x[k-1];
                    body_y[k] <= body_y[k-1];
                end
                body_x[0] <= next_x_r;
                body_y[0] <= next_y_r;
                // grow when food is eaten
                if(is_eaten_r && length < MAX_LEN)
                    length <= length + 1;
            end
        end
    end



    // Plant position - block level
    wire [$clog2(GRID_X)-1:0] famer_plant_x;
    wire [$clog2(GRID_Y)-1:0] famer_plant_y;
    reg [$clog2(GRID_X)-1:0] plant_x;
    reg [$clog2(GRID_Y)-1:0] plant_y;
    // farmer - food allocation - block level
    always @(posedge clk) begin
        if((is_eaten_r && tick_d) || reset) begin // if not on the snake & not eating food
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


    // read ports - query, anyone reads by giving an address
    reg on_snake_q;
    always @(*) begin
        on_snake_q = 0;
        for(k = 0; k < MAX_LEN; k = k + 1) begin
            if((k < length) && (body_x[k] == x) && (body_y[k] == y)) begin
                on_snake_q = 1;
            end
        end
    end

    
    assign on_snake = on_snake_q;
    assign is_head =  (body_x[0] == x) && (body_y[0] == y);
    assign is_food =  (x == plant_x) && (y == plant_y);
    assign score = length;
    assign is_eaten = (next_x == plant_x) && (next_y == plant_y);

endmodule