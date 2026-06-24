`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Game_Tick #(parameter TICK_MAX = 14285714)( // 7Hz tick for 100MHz clock
    // Inputs
    input  wire clk,
    input  wire reset,
    // Outputs
    output reg  tick
    );

    reg [23:0] cnt;
    
    always @(posedge clk) begin
        if (reset) begin 
            cnt <= 0;
            tick <= 0; 
        end else begin
            if (cnt == TICK_MAX-1) begin 
                cnt <= 0; tick <= 1; 
            end else begin 
                cnt <= cnt + 1; 
                tick <= 0; 
            end
        end
    end
endmodule