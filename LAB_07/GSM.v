`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
//    Game State Machine
//////////////////////////////////////////////////////////////////////////////////


module GSM(
    input clk,
    input reset,
    input crash,
    );
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    reg [1:0] state = IDLE;
    

    always @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
        end else begin

        end
    end


    // delete me

endmodule