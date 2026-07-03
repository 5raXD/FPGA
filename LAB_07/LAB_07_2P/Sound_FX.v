`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Sound_FX
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Square-wave sound effects on a Pmod pin (JA1). Wire a
//                  passive piezo buzzer / small speaker between JA1 and GND.
//
//                  Three effects, each a short sequence of notes:
//                    eat   : E6 (1319 Hz) for 80 ms          - blip
//                    bonus : G6 -> C7, 60 ms each            - rising chirp
//                    death : B4 -> E4 -> A3, 150/150/250 ms  - descending
//
//                  A note is {half-period in clk cycles, duration}. The
//                  output toggles every half-period while dur counts down.
//                  Death overrides anything; eat/bonus only start when idle.
//////////////////////////////////////////////////////////////////////////////////

module Sound_FX(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire trig_eat,     // 1-clk pulses
    input  wire trig_bonus,
    input  wire trig_death,
    // Outputs
    output reg  spk
    );

    // half-periods: 100 MHz / (2 * f)
    localparam [17:0] HP_E6 = 18'd37907;   // 1319 Hz
    localparam [17:0] HP_G6 = 18'd31888;   // 1568 Hz
    localparam [17:0] HP_C7 = 18'd23889;   // 2093 Hz
    localparam [17:0] HP_B4 = 18'd101215;  //  494 Hz
    localparam [17:0] HP_E4 = 18'd151515;  //  330 Hz
    localparam [17:0] HP_A3 = 18'd227273;  //  220 Hz

    // durations in clk cycles
    localparam [24:0] D_80MS  = 25'd8_000_000;
    localparam [24:0] D_60MS  = 25'd6_000_000;
    localparam [24:0] D_150MS = 25'd15_000_000;
    localparam [24:0] D_250MS = 25'd25_000_000;

    localparam SEQ_NONE = 2'd0, SEQ_EAT = 2'd1, SEQ_BONUS = 2'd2, SEQ_DEATH = 2'd3;

    reg [1:0]  seq;
    reg [1:0]  step;
    reg [17:0] half, phase;
    reg [24:0] dur;

    wire busy = (dur != 0);

    always @(posedge clk) begin
        if (reset) begin
            seq   <= SEQ_NONE;
            step  <= 0;
            dur   <= 0;
            phase <= 0;
            spk   <= 0;
        end else if (trig_death) begin                 // overrides anything
            seq  <= SEQ_DEATH; step <= 0;
            half <= HP_B4;     dur  <= D_150MS;
            phase <= 0;
        end else if (!busy && trig_bonus) begin
            seq  <= SEQ_BONUS; step <= 0;
            half <= HP_G6;     dur  <= D_60MS;
            phase <= 0;
        end else if (!busy && trig_eat) begin
            seq  <= SEQ_EAT;   step <= 0;
            half <= HP_E6;     dur  <= D_80MS;
            phase <= 0;
        end else if (busy) begin
            dur <= dur - 1;
            // square wave generation
            if (phase == 0) begin
                spk   <= ~spk;
                phase <= half;
            end else
                phase <= phase - 1;
            // note finished -> next note of the sequence (if any)
            if (dur == 1) begin
                case (seq)
                    SEQ_BONUS:
                        if (step == 0) begin
                            step <= 1; half <= HP_C7; dur <= D_60MS; phase <= 0;
                        end
                    SEQ_DEATH:
                        if (step == 0) begin
                            step <= 1; half <= HP_E4; dur <= D_150MS; phase <= 0;
                        end else if (step == 1) begin
                            step <= 2; half <= HP_A3; dur <= D_250MS; phase <= 0;
                        end
                    default: ;                          // sequence over
                endcase
            end
        end else
            spk <= 0;                                   // idle - pin low
    end

endmodule
