`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module LFSR_Food #(GRID_X = 100, GRID_Y = 75)(
    input clk,
    // input from keyboard to be used to enhance Randomness
    input keyPressed,
    output [6:0] food_x,
    output [6:0] food_y
);

    reg [15:0] lfsr = 16'hABCD;

    always @(posedge clk) begin
        lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]^keyPressed};
    end

    assign food_x = lfsr[6:0] % GRID_X;
    assign food_y = lfsr[13:7] % GRID_Y;

endmodule