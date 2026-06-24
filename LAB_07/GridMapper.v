`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper(
    // Inputs
    input  wire        clk,
    input  wire        reset,

    // Outputs
    output wire grid_enable,
    );

    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin

        end
    end

    // snake location - block level


    // farmer - food allocation - block level
    //      food generator


    // pixel color assignment - case for display layers (background, snake, food)


endmodule