`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Saleh Khalil, Mahmood Stitia
// Module:    GridMapper   (after_C_debug)
//
// Pure colour mapper now: the FSM moved to game_FSM, so GridMapper just turns the
// current game_state + cell queries into a block colour. IDLE shows welcome.mem,
// GAME_OVER shows skull.mem, PLAY shows the snake/food/grid. See changes.html.
//////////////////////////////////////////////////////////////////////////////////

module GridMapper #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire [1:0] game_state,
    input  wire [$clog2(GRID_X)-1:0] x,
    input  wire [$clog2(GRID_Y)-1:0] y,
    input  wire is_food,
    input  wire on_snake,
    input  wire is_head,
    // Outputs
    output wire grid_enable,
    output reg  [11:0] block_color
    );

    // FSM states (must match game_FSM)
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam WHITE = 12'hFFF;
    localparam BLACK = 12'h000;
    localparam GREEN = 12'h0F0;
    localparam FOOD_COLOR = 12'hF11;
    localparam SNAKE_COLOR = 12'h333;
    localparam SNAKE_HEAD_COLOR = 12'hFF0; // unique colour for the head (yellow)
    localparam WELCOME_FG = 12'h3F6;       // green text
    localparam WELCOME_BG = 12'h012;       // dark background

    // Welcome screen bitmap (IDLE)
    reg [GRID_X-1:0] welcome [0:GRID_Y-1];
    initial $readmemb("welcome.mem", welcome);
    wire on_welcome = welcome[y][GRID_X-1-x];

    // Game over screen - skull bitmap (GAME_OVER)
    reg [GRID_X-1:0] skull [0:GRID_Y-1];
    initial $readmemb("skull.mem", skull);
    wire on_skull = skull[y][GRID_X-1-x];

    // block colour assignment
    always @(*) begin
        case (game_state)
            IDLE: block_color = on_welcome ? WELCOME_FG : WELCOME_BG;
            PLAY: begin
                // priority matters: the head cell is also "on_snake"
                if      (is_head)  block_color = SNAKE_HEAD_COLOR; // snake head
                else if (on_snake) block_color = SNAKE_COLOR;      // snake body
                else if (is_food)  block_color = FOOD_COLOR;       // food
                else               block_color = GREEN;            // background
            end
            GAME_OVER: block_color = on_skull ? WHITE : BLACK;
            default:   block_color = BLACK;
        endcase
    end

    // grid lines are only drawn during play
    assign grid_enable = (game_state == PLAY);

endmodule
