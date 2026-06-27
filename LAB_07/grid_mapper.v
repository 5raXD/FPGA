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
    localparam FOOD   = 12'hF11;
    localparam SNAKE_COLOR = 12'h333;

    reg [1:0] state = IDLE;
    reg [$clog2(GRID_X * GRID_Y)-1:0] score = 0;

    wire [$clog2(GRID_X)-1:0] food_x;
    wire [$clog2(GRID_Y)-1:0] food_y;

    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            // state <= IDLE; // fix me
            state <= GAME_OVER; // fix me
        end else begin
            case (state)
                IDLE: begin
                    if(keyPressed) begin
                        state <= PLAY;
                    end
                end
                // PLAY: begin
                //     if(x == food_x && y == food_y) begin
                //         score <= score + 1;
                //     end
                // end
                // GAME_OVER: begin
                //     if(keyPressed) begin
                //         state <= PLAY;
                //         score <= 0;
                //     end
                // end
            endcase

        end
    end

    // snake location - block level


    // farmer - food allocation - block level
    // always @(posedge clk) begin
    //     if(is_eaten) begin // if not on the snake & not eating food

    //     end
    // end
    //      food generator
    farmer #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) farmer(
        // Inputs
        .clk(clk),
        .keyPressed(keyPressed),
        // Outputs
        .food_x(food_x),
        .food_y(food_y)
    );


    // pixel color assignment - case for display layers (background, snake, food)

    reg [GRID_X-1:0] skull [0:GRID_Y-1];
    initial $readmemb("skull.mem", skull);

    wire in_grid  = (x < GRID_X) && (y < GRID_Y);
    wire on_skull = in_grid && skull[y][GRID_X-1-x];
    wire on_snake;
    wire is_food;

    always @(*) begin
        case (state)
            IDLE: begin
            end
            PLAY: begin
                case({on_snake, is_food})
                    2'b01: block_color = FOOD; // food
                    2'b10: block_color = SNAKE_COLOR; // snake
                    default: block_color = GREEN;
                endcase
            end
            GAME_OVER: begin
                block_color = on_skull? WHITE : BLACK;
            end

            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY || state == GAME_OVER);

endmodule