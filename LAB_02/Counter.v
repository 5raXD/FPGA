`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil , mahmood stitia
// 
// Create Date:     11/12/2018 08:59:38 PM
// Design Name:     EE3 lab1
// Module Name:     Counter
// Project Name:    Electrical Lab 3, FPGA Experiment #1
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-lcpg236C
// Tool versions:   Vivado 2016.4
// Description:     A counter that advances its reading as long as time_reading 
//                  signal is high and zeroes its reading upon init_regs=1 input.
//                  the time_reading output represents: 
//                  {dekaseconds,seconds:deciseconds,centiseconds}
// Dependencies:    Lim_Inc
//
// Revision:        2.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Counter(clk, init_regs, count_enabled, count_sample, show_sample, time_reading);

   parameter CLK_FREQ = 100000000;// in Hz
   
   
   input clk, init_regs, count_enabled, count_sample, show_sample;
   output [15:0] time_reading;

   reg [$clog2(CLK_FREQ/100)-1:0] clk_cnt;
   reg [3:0] ones_centiseconds;
   reg [3:0] tens_centiseconds;
   reg [3:0] ones_seconds;    
   reg [3:0] tens_seconds;      
   
   // FILL HERE THE LIMITED-COUNTER INSTANCES
   localparam TICKS_PER_CSEC = CLK_FREQ/100;     // = 1,000,000
   wire tick = (clk_cnt == TICKS_PER_CSEC - 1) & count_enabled;
   wire co0, co1, co2, co3;
   wire [3:0] ones_cs, tens_cs, ones_s, tens_s;
   reg [15:0] sample_reg; // sample register 

   Lim_Inc #(.L(10)) ones_cs_inc(
       .a(ones_centiseconds),
       .ci(tick),
       .sum(ones_cs),
       .co(co0)
   );
   Lim_Inc #(.L(10)) tens_cs_inc(
       .a(tens_centiseconds),
       .ci(co0),
       .sum(tens_cs),
       .co(co1)
   );
   Lim_Inc #(.L(10)) ones_s_inc(
       .a(ones_seconds),
       .ci(co1),
       .sum(ones_s),
       .co(co2)
   );
   Lim_Inc #(.L(10)) tens_s_inc(
       .a(tens_seconds),
       .ci(co2),
       .sum(tens_s),
       .co(co3)
   );
   
   //------------- Synchronous ----------------
   always @(posedge clk) begin
		// FILL HERE THE ADVANCING OF THE REGISTERS AS A FUNCTION OF init_regs, count_enabled
    if(init_regs) begin
      clk_cnt <= 0;
      // INIT DIGITS
      ones_centiseconds <= 0;
      tens_centiseconds <= 0;
      ones_seconds <= 0;
      tens_seconds <= 0;
      // INIT SAMPLE
      sample_reg <= 0;
    end else begin
      if(clk_cnt == TICKS_PER_CSEC - 1) begin
        clk_cnt <= 0;
      end else begin
        clk_cnt <= clk_cnt + 1;
      end

      // UPDATE DIGITS 
      ones_centiseconds <= ones_cs;
      tens_centiseconds <= tens_cs;
      ones_seconds <= ones_s;
      tens_seconds <= tens_s;

      // UPDATE SAMPLE
      if(count_sample) begin
        sample_reg <= {tens_seconds, ones_seconds, tens_centiseconds, ones_centiseconds};
      end
      
    end

  end


  assign time_reading = show_sample 
        ? sample_reg 
        : {tens_seconds, ones_seconds, tens_centiseconds, ones_centiseconds};

endmodule
