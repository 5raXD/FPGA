`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil, Mahmood Stitia
// 
// Create Date:     05/05/2019 01:28AM
// Design Name:     EE3 lab1
// Module Name:     Stopwatch
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool versions:   Vivado 2016.4
// Description:     Top module of the stopwatch circuit. Displays 2 independent 
//                  stopwatches on the 4 digits of the 7-segment component.
//                  Uses btnC as reset, btnU as trigger, and btnR as split button to
//                  control the currently selected stopwatch.
//                  Pressing btnL at any time - toggles the selection between the 
//                  left hand side (LHS) and the RHS stopwatches.
//                  The stopwatch's time reading is outputted using an, seg and dp signals
//                  that should be connected to the 4-digit-7-segment display and driven
//                  by 100MHz clock. 
// Dependencies:    Debouncer, Ctl, Counter, Seg_7_Display
//
// Revision:        3.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Stopwatch(clk, btnC, btnU, btnR, btnL, seg, an, dp, led_left, led_right);

    input              clk, btnC, btnU, btnR, btnL;
    output  wire [6:0] seg;
    output  wire [3:0] an;
    output  wire       dp; 
    output  wire [2:0] led_left;
    output  wire [2:0] led_right;

    wire [15:0] time_reading;
    wire trig, split, reset, toggle;
    wire trig_right, split_right, init_regs_right, count_enabled_right;
    wire trig_left, split_left, init_regs_left, count_enabled_left;
    reg selected_stopwatch;
    
	// FILL HERE INSTANTIATIONS
    wire reset, trig, split, toggle = 1'b1;

    ///////////////////////////
	// Buttons Stabilization //
    ///////////////////////////
	Debouncer #(.COUNTER_BITS(20)) debounce_reset(
	.clk(clk),
	.input_unstable(btnC),
	.output_stable(reset)
	);
	
	Debouncer #(.COUNTER_BITS(20)) debounce_trigger(
	.clk(clk),
	.input_unstable(btnU),
	.output_stable(trig)
	);
	
	Debouncer #(.COUNTER_BITS(20)) debounce_split(
	.clk(clk),
	.input_unstable(btnR),
	.output_stable(split)
	);
	
	Debouncer #(.COUNTER_BITS(20)) debounce_toggle(
	.clk(clk),
	.input_unstable(btnL),
	.output_stable(toggle)
	);

    ///////////////////////////
    //        Controls       //
    ///////////////////////////
    Ctl ctl_right(
        .clk(clk),
        .reset(reset),
        .trig(trig_right),
        .split(split_right),
        .init_regs(init_regs_right),
        .count_enabled(count_enabled_right)
    );
    Ctl ctl_left(
        .clk(clk),
        .reset(reset),
        .trig(trig_left),
        .split(split_left),
        .init_regs(init_regs_left),
        .count_enabled(count_enabled_left)
    );

    ///////////////////////////
    //   7-Segment Display   //
    ///////////////////////////
    Seg_7_Display display(
        .sw(time_reading),
        .clk(clk),
        .dp(0),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

    ///////////////////////////
    //        Counters       //
    ///////////////////////////
    



    ///////////////////////////
    ///////////////////////////
    ///////////////////////////
    ///////////////////////////
    ///////////////////////////
    ///////////////////////////
    ///////////////////////////
    ///////////////////////////


endmodule
