`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper(
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

    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            // state <= IDLE; // fix me
            state <= GAME_OVER; // fix me
        end else begin

        end
    end

    // snake location - block level


    // farmer - food allocation - block level
    //      food generator


    // pixel color assignment - case for display layers (background, snake, food)


endmodule