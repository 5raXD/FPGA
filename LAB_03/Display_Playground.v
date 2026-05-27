`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Leo Segre
// 
// Create Date:     11/04/2024
// Design Name:     EE2 lab3
// Module Name:     Display_Playground
// Project Name:    Electrical Lab 2, Week 3
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Description:     Top module of the Display_Playground circuit which 
//                  switches [15:0] are used to selecet the display values
//                  led [9:0] indicates the first digit displayed
// Dependencies:    Seg_7_Display
//
// Revision: 		1.0

//////////////////////////////////////////////////////////////////////////////////
module Display_Playground(clk, sw, seg, an, dp, led);

    input clk;
    input [15:0] sw;
    output  wire [6:0] seg;
    output  wire [3:0] an;
    output  wire       dp;
    output  reg [9:0] led;
    
    reg [15:0] fixed_sw;
    
    genvar i;
    for (i = 0; i < 4; i = i + 1) begin
        always @(*) begin
            if (sw[(i*4)+3:i*4] > 4'd9)
                fixed_sw[(i*4)+3:i*4] = 4'd9;
            else
                fixed_sw[(i*4)+3:i*4] = sw[(i*4)+3:i*4];
        end
    end
    
    always @(*) begin
        led = 0;
        case(fixed_sw[3:0])
          4'b0000: led[0] = 1'b1;
          4'b0001: led[1] = 1'b1;
          4'b0010: led[2] = 1'b1;
          4'b0011: led[3] = 1'b1;
          4'b0100: led[4] = 1'b1;
          4'b0101: led[5] = 1'b1;
          4'b0110: led[6] = 1'b1;
          4'b0111: led[7] = 1'b1;
          4'b1000: led[8] = 1'b1;
          4'b1001: led[9] = 1'b1;
          default: led = 0;
        endcase
    end
  
    Seg_7_Display display(fixed_sw, clk, 0, seg, an, dp);


endmodule
