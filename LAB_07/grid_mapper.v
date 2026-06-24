`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper #(GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    // Outputs
    output wire grid_enable,
    );

    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;


    reg [1:0] state = IDLE;
    reg [$log2(GRID_X * GRID_Y):0] score = 0;

    wire [$log2(GRID_X):0] food_x;
    wire [$log2(GRID_Y):0] food_y;

    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            // state <= IDLE; // fix me
            state <= GAME_OVER; // fix me
        end else begin

        end
    end

    // snake location - block level


    // farmer - food allocation - block level
    // always @(posedge clk) begin
    //     if() begin // if not on the snake & not eating food
        
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


endmodule