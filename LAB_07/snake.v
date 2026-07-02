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
    // Outputs - grid reads (to Pixel_Painter / GridMapper), registered
    output reg on_snake, // Query: is this snake block?
    output reg is_head, // Query: is this block the head of the snake?
    output reg is_food, // Query: is this food block?
    // Outputs - game status
    output reg crash,
    output wire [15:0] score
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    localparam MAX_LEN = 64;
    localparam LEN_W = $clog2(MAX_LEN) + 1; // 7 bits: 1..64

    // Snake data
    // the body - one coordinate per block, body[0] is the head, body[length-1] the tail
    reg [$clog2(GRID_X)-1:0] body_x [0:MAX_LEN-1];
    reg [$clog2(GRID_Y)-1:0] body_y [0:MAX_LEN-1];
    reg [LEN_W-1:0] length;
    // head position - block level
    wire [$clog2(GRID_X)-1:0] head_x = body_x[0];
    wire [$clog2(GRID_Y)-1:0] head_y = body_y[0];

    // Plant position - block level
    wire [$clog2(GRID_X)-1:0] famer_plant_x;
    wire [$clog2(GRID_Y)-1:0] famer_plant_y;
    reg [$clog2(GRID_X)-1:0] plant_x;
    reg [$clog2(GRID_Y)-1:0] plant_y;

    integer k;

    // next head position - block level (combinational from dir)
    reg [$clog2(GRID_X)-1:0] next_x;
    reg [$clog2(GRID_Y)-1:0] next_y;
    always @(*) begin
        next_x = head_x;
        next_y = head_y;
        // move the snake in the current direction
        case(dir)
            UP:    next_y = head_y - 1;
            DOWN:  next_y = head_y + 1;
            LEFT:  next_x = head_x - 1;
            RIGHT: next_x = head_x + 1;
        endcase
    end

    // ---------------------------------------------------------------------
    // Timing pipeline. The game state only advances on `tick` (8 Hz), but the
    // synthesizer still has to close dir -> adder -> 64-way compare -> 896
    // body-register CEs in a single 10 ns cycle (this was the failing path).
    // So we cut it in registers: everything the tick update needs is
    // precomputed and registered, and stays coherent because dir/body/plant
    // are stable for millions of cycles between ticks.
    //   stage 1: next_x_r/next_y_r  <= next head (from dir + head)
    //   stage 2: hit/wall/eat flags <= checks against next_*_r,
    //            next_x_rr/next_y_rr <= next_*_r (so flags and the position
    //            used to move always describe the SAME candidate cell)
    // ---------------------------------------------------------------------
    reg [$clog2(GRID_X)-1:0] next_x_r, next_x_rr;
    reg [$clog2(GRID_Y)-1:0] next_y_r, next_y_rr;
    reg hit_self_r, hit_wall_r, eat_r;

    // self-collision - does the candidate head land on the body?
    reg hit_self_c;
    always @(*) begin
        hit_self_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == next_x_r) && (body_y[k] == next_y_r))
                hit_self_c = 1;
    end

    always @(posedge clk) begin
        next_x_r   <= next_x;
        next_y_r   <= next_y;
        next_x_rr  <= next_x_r;
        next_y_rr  <= next_y_r;
        hit_self_r <= hit_self_c;
        hit_wall_r <= (next_x_r >= GRID_X) || (next_y_r >= GRID_Y);
        eat_r      <= (next_x_r == plant_x) && (next_y_r == plant_y);
    end

    always @(posedge clk) begin
        if(reset) begin
            length <= 1;
            body_x[0] <= GRID_X >>1;
            body_y[0] <= GRID_Y >>1;
            crash <= 0;
        end else if(tick && !crash) begin
            // check for crash with walls or self
            if(hit_wall_r || hit_self_r) begin
                crash <= 1;
            end else begin
                // advance the body - each block follows the one ahead of it
                for(k = MAX_LEN-1; k > 0; k = k - 1) begin
                    body_x[k] <= body_x[k-1];
                    body_y[k] <= body_y[k-1];
                end
                body_x[0] <= next_x_rr;
                body_y[0] <= next_y_rr;
                // grow when food is eaten
                if(eat_r && length < MAX_LEN)
                    length <= length + 1;
            end
        end
    end



    // farmer - food allocation - block level
    always @(posedge clk) begin
        if((eat_r && tick) || reset) begin
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


    // read ports - anyone reads by giving an address. Registered: the queried
    // grid cell (x,y) only changes every 16 clk (8 px * 2 clk/px), so one
    // cycle of latency shifts the drawn cell by half a pixel - invisible -
    // and keeps the 64-way comparator out of the VGA pixel_color path.
    reg on_snake_c;
    always @(*) begin
        on_snake_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == x) && (body_y[k] == y))
                on_snake_c = 1;
    end
    always @(posedge clk) begin
        on_snake <= on_snake_c;
        is_head  <= (body_x[0] == x) && (body_y[0] == y);
        is_food  <= (x == plant_x) && (y == plant_y);
    end
    assign score = {{(16-LEN_W){1'b0}}, length};

endmodule
