`timescale 1ns/10ps
`define WIDTH 3
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:         Saleh Khalil , mahmood stitia 
// 
// Create Date:     11/11/2018 08:59:38 PM
// Design Name:     EE3 lab1
// Module Name:     CSA_tb
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool Versions:   Vivado 2016.4
// Description:     CSA(3) test bench
// 
// Dependencies:    CSA, FA
// 
// Revision:        2.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module CSA_tb();

    reg [`WIDTH-1:0] a; 
    reg [`WIDTH-1:0] b;
    reg ci, correct, loop_was_skipped;
    wire [`WIDTH-1:0] sum;
    wire co;
    
    integer ai,bi,cii;
    
    // Instantiate the UUT (Unit Under Test)
    CSA #(`WIDTH) uut (a, b, ci, sum, co);
    
    initial begin
        correct = 1;
        loop_was_skipped = 1;
        #1
		
        for( ai=0; ai<2**`WIDTH; ai=ai+1 ) begin
            for( bi=0; bi<2**`WIDTH; bi=bi+1 ) begin
                for( cii=0; cii<=1; cii=cii+1 ) begin
                    // FILL HERE :   a=...   b=....  
		            a = ai[`WIDTH-1:0]; b = bi[`WIDTH-1:0] ; ci = cii[0];
				    #5 
					// FILL HERE :  correct = ....
					correct = correct & (a + b + ci == {co,sum});
                    loop_was_skipped = 0;
					
                end
            end
        end
    
	
        if (correct && ~loop_was_skipped)
            $display("Test Passed - %m");
        else
            $display("Test Failed - %m");
        $finish;
    end
endmodule
