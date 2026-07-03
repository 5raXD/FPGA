`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Snake
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     One snake (body storage, movement, collision). Two are
//                  instantiated for the 2-player game. Differences vs the
//                  1-player version:
//                    - START_X/START_Y parameters (each player spawns on
//                      their own side).
//                    - food moved out to Food_Manager: eat_norm/eat_bonus
//                      come in stage-2 aligned, ate_* pulses go out at the
//                      tick for scoring/respawn.
//                    - hit_other input + (qx,qy)->q_hit query port so each
//                      snake can be tested against the other's body.
//                    - (fx,fy)->f_hit query port for food spawn free-cell
//                      checks.
//                    - freeze input: stops the survivor when the game ends.
//////////////////////////////////////////////////////////////////////////////////

module Snake #(parameter GRID_X = 100, GRID_Y = 75,
               START_X = 50, START_Y = 37)(
    // Inputs
    input wire clk,
    input wire reset,
    input wire tick,
    input wire freeze,                     // game over - nobody moves
    input wire [1:0] dir,
    // Inputs - eat flags from Food_Manager (stage-2 aligned with hit_*_r)
    input wire eat_norm,
    input wire eat_bonus,
    // Inputs - did I run into the other snake? (stage-2 aligned, from top)
    input wire hit_other,
    // Query port - other snake's candidate head vs MY body (cross collision)
    input wire [$clog2(GRID_X)-1:0] qx,
    input wire [$clog2(GRID_Y)-1:0] qy,
    output reg q_hit,                      // registered (stage-2 aligned)
    // Query port - food spawn candidate vs MY body (free-cell check)
    input wire [$clog2(GRID_X)-1:0] fx,
    input wire [$clog2(GRID_Y)-1:0] fy,
    output reg f_hit,                      // registered (1 clk latency)
    // Query port - (x,y) from Pixel_Painter: is this pixel on the snake?
    input wire [$clog2(GRID_X)-1:0] x,
    input wire [$clog2(GRID_Y)-1:0] y,
    output reg on_snake,                   // registered
    output reg is_head,                    // registered
    // Outputs - stage-1 candidate head (to cross checks + eat detection)
    output reg [$clog2(GRID_X)-1:0] next_x_r,
    output reg [$clog2(GRID_Y)-1:0] next_y_r,
    // Outputs - game status
    output reg crash,
    output reg ate_norm,                   // 1-clk pulse: ate normal food
    output reg ate_bonus,                  // 1-clk pulse: ate bonus food
    output wire [6:0] length_o
    );

    localparam UP    = 2'b00;
    localparam DOWN  = 2'b01;
    localparam LEFT  = 2'b10;
    localparam RIGHT = 2'b11;

    localparam MAX_LEN = 64;
    localparam LEN_W = $clog2(MAX_LEN) + 1; // 7 bits: 1..64

    // Snake data
    // the body - one coordinate per block, body[0] is the head, body[length-1] the tail
    reg [$clog2(GRID_X)-1:0] body_x [0:MAX_LEN-1];
    reg [$clog2(GRID_Y)-1:0] body_y [0:MAX_LEN-1];
    reg [LEN_W-1:0] length;
    // head position - block level
    wire [$clog2(GRID_X)-1:0] head_x = body_x[0];
    wire [$clog2(GRID_Y)-1:0] head_y = body_y[0];

    integer k;

    // next head position - block level (combinational from dir)
    reg [$clog2(GRID_X)-1:0] next_x;
    reg [$clog2(GRID_Y)-1:0] next_y;
    always @(*) begin
        next_x = head_x;
        next_y = head_y;
        // move the snake in the current direction
        case(dir)
            UP:    next_y = head_y - 1;
            DOWN:  next_y = head_y + 1;
            LEFT:  next_x = head_x - 1;
            RIGHT: next_x = head_x + 1;
        endcase
    end

    // ---------------------------------------------------------------------
    // Timing pipeline (same trick as the 1P version). The game state only
    // advances on `tick` (8 Hz), but the synthesizer still has to close
    // dir -> adder -> 64-way compare -> 896 body-register CEs in one 10 ns
    // cycle. So we cut it in registers: everything the tick update needs is
    // precomputed and registered, and stays coherent because dir/body are
    // stable for millions of cycles between ticks.
    //   stage 1: next_x_r/next_y_r  <= next head (from dir + head)
    //   stage 2: hit/wall flags     <= checks against next_*_r,
    //            next_x_rr/next_y_rr <= next_*_r (so flags and the position
    //            used to move always describe the SAME candidate cell)
    // The cross-snake hit (hit_other) and the eat flags are computed outside
    // from next_*_r and arrive registered too, i.e. stage-2 aligned.
    // ---------------------------------------------------------------------
    reg [$clog2(GRID_X)-1:0] next_x_rr;
    reg [$clog2(GRID_Y)-1:0] next_y_rr;
    reg hit_self_r, hit_wall_r;

    // self-collision - does the candidate head land on the body?
    reg hit_self_c;
    always @(*) begin
        hit_self_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == next_x_r) && (body_y[k] == next_y_r))
                hit_self_c = 1;
    end

    always @(posedge clk) begin
        next_x_r   <= next_x;
        next_y_r   <= next_y;
        next_x_rr  <= next_x_r;
        next_y_rr  <= next_y_r;
        hit_self_r <= hit_self_c;
        hit_wall_r <= (next_x_r >= GRID_X) || (next_y_r >= GRID_Y);
    end

    wire can_move = !(hit_wall_r || hit_self_r || hit_other);

    always @(posedge clk) begin
        ate_norm  <= 0;
        ate_bonus <= 0;
        if(reset) begin
            length <= 1;
            body_x[0] <= START_X;
            body_y[0] <= START_Y;
            crash <= 0;
        end else if(tick && !crash && !freeze) begin
            // check for crash with walls, self or the other player
            if(!can_move) begin
                crash <= 1;
            end else begin
                // advance the body - each block follows the one ahead of it
                for(k = MAX_LEN-1; k > 0; k = k - 1) begin
                    body_x[k] <= body_x[k-1];
                    body_y[k] <= body_y[k-1];
                end
                body_x[0] <= next_x_rr;
                body_y[0] <= next_y_rr;
                // grow when food is eaten (either kind; points differ at top)
                if((eat_norm || eat_bonus) && length < MAX_LEN)
                    length <= length + 1;
                ate_norm  <= eat_norm;
                ate_bonus <= eat_bonus;
            end
        end
    end

    // cross-collision query - other snake's candidate head vs my body.
    // qx/qy are that snake's stage-1 regs, so registering here makes q_hit
    // stage-2 aligned with my own hit flags.
    reg q_hit_c;
    always @(*) begin
        q_hit_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == qx) && (body_y[k] == qy))
                q_hit_c = 1;
    end
    always @(posedge clk)
        q_hit <= q_hit_c;

    // food spawn query - candidate cell vs my body (1 clk latency, the
    // Food_Manager waits a cycle before reading)
    reg f_hit_c;
    always @(*) begin
        f_hit_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == fx) && (body_y[k] == fy))
                f_hit_c = 1;
    end
    always @(posedge clk)
        f_hit <= f_hit_c;

    // render read port - registered: the queried grid cell (x,y) only
    // changes every 16 clk (8 px * 2 clk/px), so one cycle of latency
    // shifts the drawn cell by half a pixel - invisible - and keeps the
    // 64-way comparator out of the VGA pixel_color path.
    reg on_snake_c;
    always @(*) begin
        on_snake_c = 0;
        for(k = 0; k < MAX_LEN; k = k + 1)
            if((k < length) && (body_x[k] == x) && (body_y[k] == y))
                on_snake_c = 1;
    end
    always @(posedge clk) begin
        on_snake <= on_snake_c;
        is_head  <= (body_x[0] == x) && (body_y[0] == y);
    end

    assign length_o = length;

endmodule
