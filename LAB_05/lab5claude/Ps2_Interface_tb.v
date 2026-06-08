`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Interface_tb
// Project Name:    lab5
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2016.4 / Icarus Verilog (simulation)
// Description:     Self-checking test-bench for Ps2_Interface. It EMULATES the
//                  keyboard: it drives PS2Clk and PS2Data with framed bytes
//                  (start, 8 data LSB-first, odd parity, stop) and checks that
//                    1) a make-code is decoded into "scancode";
//                    2) "keyPressed" pulses exactly ONCE on the first make-code;
//                    3) typematic auto-repeats do NOT create extra pulses;
//                    4) 0xE0 / 0xF0 prefixes are ignored (no display, no pulse);
//                    5) a press AFTER a release pulses again;
//                    6) the asynchronous reset clears the outputs even while the
//                       PS/2 clock is idle.
//
//                  Note (per the PDF): only Ps2_Interface.v is simulated.
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Interface_tb();

    // a deliberately "slow, not-free-running" keyboard clock (half period)
    localparam CLK_HALF = 5000;     // 5 us  -> 10 us period (~100 kHz, scaled)

    reg        PS2Clk;
    reg        rstn;
    reg        PS2Data;
    wire [7:0] scancode;
    wire       keyPressed;

    integer    pulses;              // counts keyPressed events
    reg        correct;            // overall pass/fail flag

    // ---- Unit Under Test ----
    Ps2_Interface uut(
        .PS2Clk(PS2Clk),
        .rstn(rstn),
        .PS2Data(PS2Data),
        .scancode(scancode),
        .keyPressed(keyPressed)
    );

    // count every keyPressed pulse (one rising edge per real press)
    always @(posedge keyPressed) pulses = pulses + 1;

    // ---- keyboard emulation helpers ----
    // drive one bit: present data while the clock is high, then make the falling
    // edge (where the host samples), hold, then return the clock high.
    task ps2_bit(input b);
        begin
            PS2Data = b;
            #(CLK_HALF) PS2Clk = 1'b0;   // falling edge -> UUT samples b
            #(CLK_HALF) PS2Clk = 1'b1;   // rising edge
        end
    endtask

    // send a full 11-bit PS/2 frame for byte d (odd parity), then idle the clock
    task send_byte(input [7:0] d);
        integer i;
        reg     p;
        begin
            p = ~^d;                     // odd parity bit
            ps2_bit(1'b0);               // start bit
            for (i = 0; i < 8; i = i + 1)
                ps2_bit(d[i]);           // data D0..D7, LSB first
            ps2_bit(p);                  // parity
            ps2_bit(1'b1);               // stop bit
            #(CLK_HALF*6) ;              // idle gap (clock stays high)
        end
    endtask

    // small self-check helper
    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                correct = 1'b0;
                $display("  [FAIL] %0s", msg);
            end
            else
                $display("  [ ok ] %0s", msg);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("Ps2_Interface_tb.vcd");
            $dumpvars(0, Ps2_Interface_tb);
        end

        correct = 1'b1;
        pulses  = 0;
        PS2Clk  = 1'b1;              // PS/2 clock idles HIGH
        PS2Data = 1'b1;             // data idles HIGH
        rstn    = 1'b0;             // start in reset (async)
        #(CLK_HALF*4);
        rstn    = 1'b1;             // release reset
        #(CLK_HALF*4);

        // 1) first press of key '5' (make = 0x2E): scancode=2E, exactly 1 pulse
        $display("Test 1: first make-code 0x2E");
        send_byte(8'h2E);
        check(scancode == 8'h2E, "scancode == 0x2E");
        check(pulses   == 1,     "keyPressed pulsed once");

        // 2) typematic auto-repeat: same code twice more, NO new pulses
        $display("Test 2: typematic repeats of 0x2E");
        send_byte(8'h2E);
        send_byte(8'h2E);
        check(scancode == 8'h2E, "scancode still 0x2E");
        check(pulses   == 1,     "no extra pulses on repeats");

        // 3) extended key 0xE0 0x5A: ignore 0xE0, show 0x5A, one new pulse
        $display("Test 3: extended key 0xE0,0x5A");
        send_byte(8'hE0);
        check(scancode == 8'h2E, "0xE0 did not change scancode");
        check(pulses   == 1,     "0xE0 did not pulse");
        send_byte(8'h5A);
        check(scancode == 8'h5A, "scancode updated to 0x5A");
        check(pulses   == 2,     "trailing byte pulsed once");

        // 4) key release 0xF0 0x5A: no pulse, code held
        $display("Test 4: release 0xF0,0x5A");
        send_byte(8'hF0);
        check(pulses   == 2,     "0xF0 did not pulse");
        send_byte(8'h5A);
        check(scancode == 8'h5A, "scancode unchanged on release");
        check(pulses   == 2,     "release did not pulse");

        // 5) press the SAME key again after the release: must pulse again
        $display("Test 5: re-press 0x5A after release");
        send_byte(8'h5A);
        check(scancode == 8'h5A, "scancode == 0x5A");
        check(pulses   == 3,     "re-press pulsed again");

        // 6) asynchronous reset clears outputs (even with PS2Clk idle)
        $display("Test 6: asynchronous reset");
        rstn = 1'b0;                 // assert while PS2Clk is idle high
        #1;
        check(scancode   == 8'h00, "scancode cleared by async reset");
        check(keyPressed == 1'b0,  "keyPressed low after reset");
        #(CLK_HALF*2);
        rstn = 1'b1;

        if (correct) $display("Test Passed - %m");
        else         $display("Test Failed - %m");
        $finish;
    end

endmodule
