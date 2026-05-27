`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:       Saleh Khalil , mahmood stitia 
// 
// Create Date:     11/10/2018 08:59:38 PM
// Design Name:     EE3 lab1
// Module Name:     CSA
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool Versions:   Vivado 2016.4
// Description:     Variable length binary adder. The parameter N determines
//                  the bit width of the operands. Implemented according to 
//                  Conditional Sum Adder.
// 
// Dependencies:    FA
// 
// Revision:        2.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module CSA(a, b, ci, sum, co);

    parameter N=4;
    parameter K = N >> 1;
    
    input [N-1:0] a;
    input [N-1:0] b;
    input ci;
    output [N-1:0] sum;
    output co;
    
	
    // FILL HERE
    generate 
        if (N!=1) begin
            wire [K-1:0] s_r;
            wire carry_r;
            wire [N-K-1:0] s_l0;
            wire carry_l0;
            wire [N-K-1:0] s_l1;
            wire carry_l1;
            //right case (alice)
            CSA #(K) csa_r(a[K-1:0],b[K-1:0],ci,s_r,carry_r);
            //left case (bob)
            CSA #(N-K) csa_l0(a[N-1:K],b[N-1:K],1'b0,s_l0,carry_l0);
            CSA #(N-K) csa_l1(a[N-1:K],b[N-1:K],1'b1,s_l1,carry_l1);
            //choose the correct case
            assign sum[K-1:0] = s_r;
            assign sum[N-1:K] = (carry_r==1'b1)?s_l1:s_l0;
            assign co = (carry_r==1'b1)?carry_l1:carry_l0;
        end else begin ;
            FA fa(a,b,ci,sum,co);

        end
     endgenerate
    
endmodule
