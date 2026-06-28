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
    input wire crash,
    input wire is_food,
    input wire on_snake,
    input wire is_head,
    // Outputs
    output wire grid_enable,
    output reg  [11:0] block_color
    );

    // FSM states
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam WHITE = 12'hFFF;
    localparam BLACK = 12'h000;
    localparam GREEN = 12'h0F0;
    localparam FOOD_COLOR = 12'hF11;
    localparam SNAKE_COLOR = 12'h333;
    localparam SNAKE_HEAD_COLOR = 12'hCCC; // light grey - distinct from the body

    reg [1:0] state = IDLE;
    reg [$clog2(GRID_X * GRID_Y)-1:0] score = 0;


    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:      state <= keyPressed? PLAY : IDLE;
                PLAY:      state <= crash? GAME_OVER : PLAY;
                GAME_OVER: state <= keyPressed? IDLE : GAME_OVER;
            endcase

        end
    end


    // Idle screen - game welocome screen
    reg [GRID_X-1:0] welcome [0:GRID_Y-1];
    initial $readmemb("welcome.mem", welcome);


    // Game over screen - skull bitmap
    reg [GRID_X-1:0] skull [0:GRID_Y-1];
    initial $readmemb("skull.mem", skull);
    wire on_skull = skull[y][GRID_X-1-x];


    // block color assignment - case for display layers (background, snake, food)
    always @(*) begin
        case (state)
            IDLE: block_color = BLACK;
            PLAY: begin
                // priority order: is_head implies on_snake, so it must win first
                if(is_food)       block_color = FOOD_COLOR;       // food
                else if(is_head)  block_color = SNAKE_HEAD_COLOR; // head
                else if(on_snake) block_color = SNAKE_COLOR;      // body
                else              block_color = GREEN;            // background
            end
            GAME_OVER: begin
                block_color = on_skull? WHITE : BLACK;
            end
            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY);

endmodule