`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Game_Tick #(parameter TICK_MAX = 14_285_714)( // 7Hz tick for 100MHz clock
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire [15:0] score,
    // Outputs
    output reg  tick
    );

    localparam TICK_INC = 262_144;
    localparam MAX_STEPS = (TICK_MAX-1)/TICK_INC;

    reg [$clog2(TICK_MAX)-1:0] cnt;
    reg [$clog2(TICK_MAX)-1:0] tick_speed = TICK_MAX; // starts from 7Hz tick

    wire [$clog2(TICK_MAX)-1:0] cnt_inc;
    Lim_Inc #(.L(TICK_MAX)) cnt_incrementer (
        .a(cnt),
        .ci(1'b1),
        .sum(cnt_inc),
        .co()
    );

    always @(posedge clk) begin
        if (score < MAX_STEPS)
            tick_speed <= TICK_MAX - score * TICK_INC;
        else
            tick_speed <= TICK_MAX - MAX_STEPS * TICK_INC;
    end

    always @(posedge clk) begin
        if (reset) begin
            cnt <= 0;
            tick <= 0;
        end else if (cnt >= tick_speed - 1) begin
            cnt <= 0;
            tick <= 1;
        end else begin
            cnt <= cnt_inc;
            tick <= 0;
        end
    end
endmodule