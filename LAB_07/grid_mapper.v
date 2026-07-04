`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire keyPressed,
    input  wire [$clog2(GRID_X)-1:0] x,
    input  wire [$clog2(GRID_Y)-1:0] y,
    input  wire [$clog2(2*GRID_X)-1:0] img_x,
    input  wire [$clog2(2*GRID_Y)-1:0] img_y,
    input wire crash,
    input wire is_food,
    input wire on_snake,
    input wire is_head,
    // Outputs
    output wire grid_enable,
    output wire in_idle,                  // hold the snake in reset on the welcome screen
    output reg  [11:0] block_color
    );

    // FSM states
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam WHITE = 12'hFFF;
    localparam BLACK = 12'h000;
    localparam GREEN_EVEN = 12'h0C0; // Dark green
    localparam GREEN_ODD = 12'h0F0; // Light green
    localparam FOOD_COLOR = 12'hF11;
    localparam SNAKE_COLOR = 12'h333;
    localparam SNAKE_HEAD_COLOR = 12'hFD0; // unique head color - warm yellow
    localparam SKULL_COLOR = 12'hEEC;
    localparam DIED_COLOR = 12'hE11;
    localparam WELCOME_BRIGHT = 12'h6E2;
    localparam WELCOME_DARK = 12'h021;

    reg [1:0] state = IDLE;

    // Chess-board background: a cell is "odd" when x+y is odd. The LSB of
    // x+y is the sum output of a full adder with carry-in 0 (= x[0]^y[0]).
    wire odd_block;

    FA fa(
    .a(x[0]),
    .b(y[0]),
    .ci(1'b0),
    .sum(odd_block),
    .co()          // carry unused - only the parity matters
    );


    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin
            case (state)
                // NOTE: keep these plain ternaries. Writing them as
                // "state <= key ? PLAY : state <= IDLE" parses the inner <=
                // as LESS-THAN-OR-EQUAL and the FSM can never hold a state.
                IDLE:      state <= keyPressed ? PLAY      : IDLE;
                PLAY:      state <= crash      ? GAME_OVER : PLAY;
                GAME_OVER: state <= keyPressed ? IDLE      : GAME_OVER;
                default:   state <= IDLE;
            endcase
        end
    end


    // Idle screen - game welcome screen (200x150, sampled at img_x = XCoord>>2)
    reg [2*GRID_X-1:0] welcome [0:2*GRID_Y-1];
    initial $readmemb("welcome45_raw_200x150.mem", welcome);

    // Game over screen - skull bitmap
    reg [2*GRID_X-1:0] skull [0:2*GRID_Y-1];
    initial $readmemb("skull_you_died_200x150.mem", skull);

    // Bitmap reads registered: keeps the big LUT-ROM muxes out of the
    // pixel_color timing path. 1 clk of latency = half a pixel, invisible.
    reg on_welcome, on_skull, died_zone;
    always @(posedge clk) begin
        on_welcome <= welcome[img_y][2*GRID_X-1-img_x];
        on_skull   <= skull[img_y][2*GRID_X-1-img_x];
        died_zone  <= (img_y >= 100);     // below the skull: the "YOU DIED" text
    end


    // block color assignment - case for display layers (background, snake, food)
    // In PLAY the flags are NOT mutually exclusive (the head is also on_snake),
    // so it must be a priority chain: head > food > body > background.
    always @(*) begin
        case (state)
            IDLE: begin
                block_color = on_welcome ? WELCOME_BRIGHT : WELCOME_DARK;
            end
            PLAY: begin
                if      (is_head)  block_color = SNAKE_HEAD_COLOR;
                else if (is_food)  block_color = FOOD_COLOR;
                else if (on_snake) block_color = SNAKE_COLOR;
                else               block_color = odd_block ? GREEN_ODD : GREEN_EVEN;
            end
            GAME_OVER: begin
                block_color = on_skull ? (died_zone ? DIED_COLOR : SKULL_COLOR) : BLACK;
            end
            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY);
    assign in_idle     = (state == IDLE);

endmodule
