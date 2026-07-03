`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Direction_Ctrl
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Direction register with correct no-reversal rule.
//                  One instance per player; the request inputs are 1-clk
//                  pulses (decoded PS/2 scancodes for P1, debounced board
//                  buttons for P2).
//
//                  Reversal-bug fix: a naive guard compares the new request
//                  against the *current* dir register, which may already hold
//                  a not-yet-applied turn. Two quick presses inside one tick
//                  window (e.g. RIGHT: press UP then LEFT) then pass both
//                  checks and the snake reverses 180 deg into its own neck.
//                  Here every request is validated against dir_committed -
//                  the direction the snake ACTUALLY moved on the last tick -
//                  so an illegal reversal is impossible no matter how fast
//                  the keys come in.
//
//                  dir_committed is latched at each tick from dir delayed by
//                  two clocks (dir_d2), matching the Snake module's 2-stage
//                  next-head pipeline: the position applied at a tick was
//                  computed from dir as it was 2 clk earlier, so dir_d2 at
//                  the tick edge is exactly the direction that was applied.
//////////////////////////////////////////////////////////////////////////////////

module Direction_Ctrl #(parameter START_DIR = 2'b11)( // default RIGHT
    input  wire clk,
    input  wire reset,
    input  wire tick,        // 1-clk pulse - the snake moves on this edge
    input  wire req_up,
    input  wire req_down,
    input  wire req_left,
    input  wire req_right,
    output reg  [1:0] dir
    );

    localparam UP    = 2'b00;
    localparam DOWN  = 2'b01;
    localparam LEFT  = 2'b10;
    localparam RIGHT = 2'b11;

    reg [1:0] dir_d1, dir_d2;     // dir delayed 2 clk (Snake pipeline depth)
    reg [1:0] dir_committed;      // direction of the last executed move

    // On the tick cycle itself the committed value is being replaced by
    // dir_d2 (this very move); validate a same-cycle request against that,
    // otherwise a press landing exactly on the tick edge would be checked
    // against a one-move-old direction.
    wire [1:0] committed_now = tick ? dir_d2 : dir_committed;

    always @(posedge clk) begin
        if (reset) begin
            dir           <= START_DIR;
            dir_d1        <= START_DIR;
            dir_d2        <= START_DIR;
            dir_committed <= START_DIR;
        end else begin
            dir_d1 <= dir;
            dir_d2 <= dir_d1;
            if (tick)
                dir_committed <= dir_d2;

            // opposite(d) = d ^ 2'b01 with this encoding
            if      (req_up    && committed_now != DOWN ) dir <= UP;
            else if (req_down  && committed_now != UP   ) dir <= DOWN;
            else if (req_left  && committed_now != RIGHT) dir <= LEFT;
            else if (req_right && committed_now != LEFT ) dir <= RIGHT;
        end
    end

endmodule
