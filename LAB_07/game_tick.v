`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Game_Tick #(parameter TICK_MAX = 14285714)( // 7Hz tick for 100MHz clock
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire [15:0] score,
    // Outputs
    output reg  tick
    );

    localparam TICK_INC = 184_151;

    reg [$clog2(TICK_MAX + 64*TICK_INC)-1:0] cnt;
    reg [$clog2(TICK_MAX + 64*TICK_INC)-1:0] tick_speed = TICK_MAX + 63*TICK_INC; // 7Hz tick for 100MHz clock

    always @(posedge clk) begin
        if (score < 64)
            tick_speed <= TICK_MAX + (64 - score) * TICK_INC;
        else
            tick_speed <= TICK_MAX;
    end

    always @(posedge clk) begin
        if (reset) begin
            cnt <= 0;
            tick <= 0;
        end else begin
            if (cnt >= tick_speed-1) begin
                cnt <= 0;
                tick <= 1;
            end else begin
                cnt <= cnt + 1;
                tick <= 0;
            end
        end
    end
endmodule