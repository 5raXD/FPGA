`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Interface
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     PS/2 keyboard receiver.
//                  Receives the serial PS/2 frames coming from the numeric
//                  keypad, extracts the 8-bit make-code (scancode) of the most
//                  recently pressed key and raises a one-(PS2Clk)-cycle pulse
//                  "keyPressed" at the moment the FIRST make-code packet of a new
//                  press is received.
//
//                  PS/2 frame (11 bits, sent LSB first, sampled on the falling
//                  edge of PS2Clk):
//                      bit 0      : start  (always 0)
//                      bit 1..8   : data D0..D7 (LSB first)
//                      bit 9      : parity (odd)  - ignored here
//                      bit 10     : stop   (always 1)
//
//                  The keyboard clock (PS2Clk) is NOT free running: it toggles
//                  only while a byte is being transmitted and is idle (high) the
//                  rest of the time. Therefore:
//                    * the whole logic of this module is clocked by PS2Clk;
//                    * the reset is ASYNCHRONOUS and active low (rstn), so the
//                      design can be reset even while PS2Clk is idle;
//                    * the packet is decoded ON the stop-bit edge (the last edge
//                      that the keyboard actually produces) - we never wait for an
//                      edge that comes AFTER the stop bit, because none does.
//
// Dependencies:    None
//
// Revision:        1.0
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Interface(
    input  wire       PS2Clk,      // keyboard clock - used AS A CLOCK here
    input  wire       rstn,        // active-low ASYNCHRONOUS reset
    input  wire       PS2Data,     // keyboard serial data
    output reg  [7:0] scancode,    // most recent make-code byte
    output reg        keyPressed   // 1-cycle pulse on the first make of a new press
    );

    // 22-bit shift register: holds the current 11-bit frame plus the previous one,
    // so that two-frame sequences (0xE0 / 0xF0 prefixes) can be recognised.
    reg [21:0] shiftreg;
    reg [3:0]  bitcount;           // counts the 11 bits of one frame (0..10)

    // State used to tell a genuine NEW press from a typematic auto-repeat.
    reg [7:0]  held_code;          // make-code of the key currently held down
    reg        key_down;           // 1 while a key is considered pressed

    // We act on the STOP-bit edge. At that edge the non-blocking assignment of
    // "shiftreg" still evaluates the OLD (pre-shift) value, which already holds
    // the 10 bits start..parity of the current frame plus the full previous
    // frame below it. With the right shift used below those bits sit at:
    //
    //   current  frame : start=sr[12], D0..D7=sr[13..20], parity=sr[21]
    //   previous frame : start=sr[1] , D0..D7=sr[2..9] , parity=sr[10], stop=sr[11]
    //
    // so the two data bytes are the contiguous slices below.
    wire [7:0] current_byte  = shiftreg[20:13];
    wire [7:0] previous_byte = shiftreg[9:2];

    wire frame_done = (bitcount == 4'd10);   // this edge receives the stop bit

    localparam [7:0] EXTEND = 8'hE0;   // extended-key prefix
    localparam [7:0] BREAK  = 8'hF0;   // break (key-release) prefix

    always @(negedge PS2Clk or negedge rstn) begin
        if (!rstn) begin
            shiftreg   <= 22'd0;
            bitcount   <= 4'd0;
            scancode   <= 8'd0;
            keyPressed <= 1'b0;
            held_code  <= 8'd0;
            key_down   <= 1'b0;
        end
        else begin
            // shift the serial bit in, LSB first -> new bit enters at the MSB
            shiftreg <= {PS2Data, shiftreg[21:1]};

            // keyPressed is a pulse: default low, raised only on a real new press
            keyPressed <= 1'b0;

            if (frame_done) begin
                bitcount <= 4'd0;

                if (current_byte == EXTEND || current_byte == BREAK) begin
                    // 0xE0 / 0xF0 are only prefixes: do not display, do not pulse.
                    // (0xF0 marks that the NEXT make-code is a release event.)
                end
                else if (previous_byte == BREAK) begin
                    // make-code that follows 0xF0  ->  key RELEASE.
                    // Do not pulse and keep showing the last code; just remember
                    // that the key is now up so the next press pulses again.
                    key_down <= 1'b0;
                end
                else begin
                    // a real make-code (a key is down). Always show the latest.
                    scancode <= current_byte;
                    if (!key_down || current_byte != held_code) begin
                        // first make-code of a NEW press -> single pulse
                        keyPressed <= 1'b1;
                        key_down   <= 1'b1;
                        held_code  <= current_byte;
                    end
                    // else: typematic auto-repeat of the same key -> no pulse
                end
            end
            else begin
                bitcount <= bitcount + 4'd1;
            end
        end
    end

endmodule
