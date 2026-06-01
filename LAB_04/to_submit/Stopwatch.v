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
    // button signals
    wire trig, split, reset, toggle;
    // counter signals
    wire trig_right, split_right, init_regs_right, count_enabled_right, count_sample_right, show_sample_right;
    wire trig_left,  split_left,  init_regs_left,  count_enabled_left, count_sample_left, show_sample_left;
    // selected stopwatch
    localparam LEFT = 1'b0, RIGHT = 1'b1;
    reg selected_stopwatch; //left -> 0; right -> 1
    
	// FILL HERE INSTANTIATIONS
    wire [15:0] time_reading_left, time_reading_right;
    // reg right_split_active, left_split_active;

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
        .x(time_reading),
        .clk(clk),
        .clr(reset),
        .a_to_g(seg),
        .an(an),
        .dp(dp) 
    );

    ///////////////////////////
    //        Counters       //
    ///////////////////////////
    Counter counter_right(
        .clk(clk),
        .init_regs(reset | init_regs_right),
        .count_enabled(count_enabled_right),
        .count_sample(count_sample_right),
        .show_sample(show_sample_right),
        .time_reading(time_reading_right)
    );
    Counter counter_left(
        .clk(clk),
        .init_regs(reset | init_regs_left),
        .count_enabled(count_enabled_left),
        .count_sample(count_sample_left),
        .show_sample(show_sample_left),
        .time_reading(time_reading_left)
    );

    ///////////////////////////
    //    Stopwatch Logic    //
    ///////////////////////////

    always @(posedge clk) begin // TOGGLE SELECTED STOPWATCH
        if(reset) begin
            selected_stopwatch <= LEFT;
            // left_split_active <= 1'b0;
            // right_split_active <= 1'b0;
        end
        else begin
            if(toggle) selected_stopwatch <= ~selected_stopwatch;
            // if(split) begin
            //     if(selected_stopwatch == RIGHT && !count_enabled_right)
            //         right_split_active <= ~right_split_active;
            //     if(selected_stopwatch == LEFT && !count_enabled_left)
            //         left_split_active <= ~left_split_active;
            // end
        end
    end


    // left stopwatch signals
	assign led_left  = (selected_stopwatch == LEFT)? 3'b111 : 3'b000; // left stopwatch is selected
    assign trig_left   = (selected_stopwatch == LEFT)? trig  : 1'b0;
    assign split_left  = (selected_stopwatch == LEFT)? split : 1'b0;
    assign show_sample_left  = 1'b0;
    assign count_sample_left = 1'b0;

    // right stopwatch signals
    assign led_right = (selected_stopwatch == RIGHT)? 3'b111 : 3'b000; // right stopwatch is selected
    assign trig_right  = (selected_stopwatch == RIGHT)? trig  : 1'b0;
    assign split_right = (selected_stopwatch == RIGHT)? split : 1'b0;
    assign show_sample_right  = 1'b0;
    assign count_sample_right = 1'b0;

    assign time_reading = {time_reading_left[15:8], time_reading_right[15:8]};

endmodule
