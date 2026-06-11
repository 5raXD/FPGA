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
    localparam CLK_HALF = 30_000;       // 30 us -> 60 us

    reg        PS2Clk;
    reg        rstn;
    reg        PS2Data;
    wire [7:0] scancode;
    wire       keyPressed;

    integer    pulses;              
    reg        correct;          

    Ps2_Interface dut(
        .PS2Clk(PS2Clk),
        .rstn(rstn),
        .PS2Data(PS2Data),
        .scancode(scancode),
        .keyPressed(keyPressed)
    );

    always #CLK_HALF PS2Clk = ~PS2Clk;  // ~16.7 kHz PS2 keyboard clock

    alwa

endmodule
