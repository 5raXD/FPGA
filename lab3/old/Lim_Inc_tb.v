`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil , mahmood stitia
// 
// Create Date:     11/12/2018 08:59:38 PM
// Design Name:     EE3 lab1
// Module Name:     Lim_Inc_tb
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool Versions:   Vivado 2016.4
// Description:     Limited incrementor test bench
// 
// Dependencies:    Lim_Inc
// 
// Revision:        2.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module Lim_Inc_tb();

    reg [3:0] a; 
    reg ci, correct, loop_was_skipped;
    wire [3:0] sum;
    wire co;
    
    integer ai,cii;

    localparam L = 10;
    
    // Instantiate the UUT (Unit Under Test)
    Lim_Inc #(L) uut(
    .a(a),
    .ci(ci),
    .sum(sum),
    .co(co)
    );
    
	//FILL HERE
    initial begin
        if ($test$plusargs("WAVE")) begin
            $dumpfile("Lim_Inc_tb.vcd");
            $dumpvars(0, Lim_Inc_tb);
        end

        correct = 1;
        loop_was_skipped = 1;
        #1
        //FILL HERE
        // a has 4 bits so will test all vlaues from 0 to 15 with both ci = 0 and ci =1
        for (ai = 0; ai<16; ai=ai+1) begin
         for (cii = 0; cii<=1; cii=cii+1) begin 
          a = ai;
          ci = cii;
          #5;
          
          if (ai >= L) correct = correct & (sum == 0) & (co == 1);
          else begin
           if (ai == L-1)  correct = correct & ( ((sum == ai) & (co == 0) & (cii == 0)) | ((sum == 0) & (co == 1) & (cii == 1)) );
           else correct = correct & (sum == ai + cii) & (co == 0);
          end
            loop_was_skipped = 0;
         end
        end
        #5
        if (correct && ~loop_was_skipped)
            $display("Test Passed - %m");
        else
            $display("Test Failed - %m");
        $finish;
    end
endmodule