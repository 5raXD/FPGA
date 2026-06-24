`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Game_Tick #(parameter TICK_MAX = 100_000_000)(  // 100MHz / 100M = 1Hz
    // Inputs
    input  wire clk,
    input  wire reset,
    // Outputs
    output reg  tick
    );

    reg [26:0] cnt;
    
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