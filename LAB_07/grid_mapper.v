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
    localparam SNAKE_HEAD_COLOR = 12'h333; // give me unique color!!!

    reg [1:0] state = IDLE;
    reg [$clog2(GRID_X * GRID_Y)-1:0] score = 0;


    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            // state <= IDLE; // fix me
            state <= GAME_OVER; // fix me
        end else begin
            case (state)
                IDLE: state <= keyPressed? PLAY : state <= IDLE;
                PLAY: state <= crash? GAME_OVER : state <= PLAY;
                GAME_OVER: state <= keyPressed? IDLE : state <= GAME_OVER;
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
            IDLE: begin
            end
            PLAY: begin
                case({on_snake, is_food, is_head})
                    3'b001: block_color = SNAKE_HEAD_COLOR; // snake head
                    3'b010: block_color = FOOD_COLOR; // food
                    3'b100: block_color = SNAKE_COLOR; // snake body
                    default: block_color = GREEN; // background
                endcase
            end
            GAME_OVER: begin
                block_color = on_skull? WHITE : BLACK;
            end
            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY);

endmodule