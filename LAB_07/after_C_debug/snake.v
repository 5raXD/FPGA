`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Saleh Khalil, Mahmood Stitia
// Module:    Snake   (after_C_debug version 2 - segment-list representation)
//
// The snake body is stored as a short LIST of segment coordinates (segment 0 is
// the head), moved like a shift register: every segment follows the one ahead of
// it. This costs ~MAX_LEN*(XW+YW) flip-flops (~1.4k) instead of the 100x75 x 13-bit
// countdown grid (~97.5k FFs + a subtractor per cell) that made synthesis thrash.
// Same module interface as before, so the rest of the project is unchanged.
// See changes.html.
//////////////////////////////////////////////////////////////////////////////////

module Snake #(parameter GRID_X = 100, GRID_Y = 75, MAX_LEN = 100)(
    // Inputs
    input wire clk,
    input wire reset,
    input wire tick,
    input wire [1:0] dir,
    input wire keyPressed,
    // Inputs - (x,y) from pixel_painter - Query: what is at this cell?
    input wire [$clog2(GRID_X)-1:0] x,
    input wire [$clog2(GRID_Y)-1:0] y,
    // Outputs - cell queries (to Pixel_Painter / GridMapper)
    output wire on_snake, // Query: is this cell part of the snake?
    output wire is_head,  // Query: is this cell the head?
    output wire is_food,  // Query: is this cell the food?
    // Outputs - game status
    output reg  crash,
    output wire [15:0] score
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    localparam XW = $clog2(GRID_X);    // coordinate widths
    localparam YW = $clog2(GRID_Y);
    localparam LW = $clog2(MAX_LEN+1); // length counter width

    // snake body: list of segment coordinates, [0] = head
    reg [XW-1:0] sx [0:MAX_LEN-1];
    reg [YW-1:0] sy [0:MAX_LEN-1];
    reg [LW-1:0] length;

    // food location - block level
    wire [XW-1:0] farmer_x;
    wire [YW-1:0] farmer_y;
    reg  [XW-1:0] plant_x;
    reg  [YW-1:0] plant_y;

    // next head position (combinational); unsigned wrap also catches the
    // left/top walls (stepping off 0 wraps to a value >= GRID).
    wire [XW-1:0] next_x = (dir == LEFT)  ? sx[0] - 1'b1 :
                           (dir == RIGHT) ? sx[0] + 1'b1 : sx[0];
    wire [YW-1:0] next_y = (dir == UP)    ? sy[0] - 1'b1 :
                           (dir == DOWN)  ? sy[0] + 1'b1 : sy[0];

    wire is_eaten = (next_x == plant_x) && (next_y == plant_y);

    // self-collision: would the next head land on an active body segment?
    integer k;
    reg hit_body;
    always @(*) begin
        hit_body = 1'b0;
        for (k = 1; k < MAX_LEN; k = k + 1)
            if (k < length && sx[k] == next_x && sy[k] == next_y)
                hit_body = 1'b1;
    end

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            length <= 1;
            crash  <= 0;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                sx[i] <= GRID_X >> 1;   // all segments start stacked at center
                sy[i] <= GRID_Y >> 1;
            end
        end else if (tick && !crash) begin
            if (next_x >= GRID_X || next_y >= GRID_Y || hit_body) begin
                crash <= 1;
            end else begin
                // shift the whole list: every segment follows the one ahead.
                // length controls how many of these segments are visible, so on
                // eat we just grow length by 1 and the next stored segment (which
                // already holds the old tail position) becomes part of the body.
                for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                    sx[i] <= sx[i-1];
                    sy[i] <= sy[i-1];
                end
                sx[0] <= next_x;
                sy[0] <= next_y;
                if (is_eaten && length < MAX_LEN)
                    length <= length + 1'b1;
            end
        end
    end

    // farmer - (re)plant food on eat (or reset)
    always @(posedge clk) begin
        if ((is_eaten && tick) || reset) begin
            plant_x <= farmer_x;
            plant_y <= farmer_y;
        end
    end

    // food generator (LFSR)
    farmer #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) farmer(
        .clk(clk),
        .keyPressed(keyPressed),
        .food_x(farmer_x),
        .food_y(farmer_y)
    );

    // combinational cell queries for the painter (comparators, not a RAM)
    integer m;
    reg on_body;
    always @(*) begin
        on_body = 1'b0;
        for (m = 0; m < MAX_LEN; m = m + 1)
            if (m < length && sx[m] == x && sy[m] == y)
                on_body = 1'b1;
    end

    assign on_snake = on_body;
    assign is_head  = (sx[0] == x) && (sy[0] == y);
    assign is_food  = (plant_x == x) && (plant_y == y);
    assign score    = length - 1'b1; // segments beyond the initial head = food eaten

endmodule
