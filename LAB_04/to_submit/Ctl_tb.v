`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil, Mahmood Stitia
//
// Create Date:     05/05/2019 02:59:38 AM
// Design Name:     EE3 lab1
// Module Name:     Ctl_tb
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool versions:   Vivado 2016.4
// Description:     test bennch for the control.
// Dependencies:    None
//
// Revision: 		3.0
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module Ctl_tb();

    reg clk, reset, trig, split, correct, loop_was_skipped;
    wire init_regs, count_enabled;


    integer ai,cii;
    localparam IDLE  = 3'b001, COUNTING = 3'b010, PAUSED = 3'b100 ;
    // Instantiate the UUT (Unit Under Test)
    // FILL HERE

    Ctl uut(
        .clk(clk),
        .reset(reset),
        .trig(trig),
        .split(split),
        .init_regs(init_regs),
        .count_enabled(count_enabled)
        );

    initial begin

        if($test$plusargs("vcd")) begin
            $dumpfile("Ctl_tb.vcd");
            $dumpvars(0, Ctl_tb);
        end

        
        correct = 1;
        loop_was_skipped = 0;
        ai = 0;
        cii = 0;
        clk = 0;
        reset = 1;
        trig = 0;
        split = 0;
        #10
        reset = 0;
        correct = correct & init_regs & ~count_enabled;
        @(posedge clk);
        // FILL HERE - TEST VARIOUS STATE TRANSITION
        loop_was_skipped = 1;
        for(ai = 0; ai < 3; ai = ai + 1) begin
            loop_was_skipped = 0;
            // state = state[ai] where
            // ai = 0 -> IDLE
            // ai = 1 -> COUNTING
            // ai = 2 -> PAUSED
            for(cii = 0; cii < 8; cii = cii + 1) begin
                reset = 1;
                #10
                reset = 0;
                if(ai != IDLE) begin
                    trig = 1;
                    #10
                    trig = 0;
                end
                if(ai == PAUSED) begin
                    trig = 1;
                    #10
                    trig = 0;
                end // make sure state = state[ai]

                {reset, trig, split} = cii;
                #10
                {reset, trig, split} = 0;
                case(ai)
                    IDLE: begin // if Started from IDLE
                        casez(cii)
                            3'b00? : correct = correct & init_regs & ~count_enabled & (uut.state == IDLE); //10
                            3'b1?? : correct = correct & init_regs & ~count_enabled & (uut.state == IDLE); //10
                            3'b01? : correct = correct & ~init_regs & count_enabled & (uut.state == COUNTING); //01
                            default: correct = 0;
                        endcase
                    end
                    COUNTING: begin // if Started from COUNTING
                        casez(cii)
                            3'b1?? : correct = correct & init_regs & ~count_enabled & (uut.state == IDLE); //10
                            3'b00? : correct = correct & ~init_regs & count_enabled & (uut.state == COUNTING); //01
                            3'b01? : correct = correct & ~init_regs & ~count_enabled & (uut.state == PAUSED); //00
                            default: correct = 0;
                        endcase
                    end
                    PAUSED: begin // if Started from PAUSED
                        casez(cii)
                            3'b1?? : correct = correct & init_regs & ~count_enabled & (uut.state == IDLE); //10
                            3'b01? : correct = correct & ~init_regs & count_enabled & (uut.state == COUNTING); //01
                            3'b001 : correct = correct & init_regs & ~count_enabled & (uut.state == IDLE); //10
                            3'b000 : correct = correct & ~init_regs & ~count_enabled & (uut.state == PAUSED); //00
                            default: correct = 0;
                        endcase
                    end
                endcase
            end
        end

        if (correct)
            $display("Test Passed - %m");
        else
            $display("Test Failed - %m");
        $finish;
    end

    always #5 clk = ~clk;

endmodule
