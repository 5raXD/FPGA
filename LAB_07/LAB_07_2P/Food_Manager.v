`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     Food_Manager
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Owns both food items on the shared field:
//                    - normal food: always present, +1 point
//                    - bonus food: appears every BONUS_PERIOD ticks, lives
//                      BONUS_LIFE ticks, +3 points (drawn flashing)
//
//                  Position source is a free-running 16-bit LFSR (taps
//                  15,13,12,10 - maximal length) with key presses mixed in
//                  for entropy. Two fixes over the 1P farmer:
//                    1. no modulo bias: out-of-range draws are simply
//                       rejected (lfsr runs at 100 MHz, a valid draw is
//                       never more than a few cycles away)
//                    2. no spawn on occupied cells: each candidate is
//                       checked against both snake bodies through their
//                       f-query ports (and against the other food) before
//                       being committed. Also keeps y >= MIN_Y so food
//                       never hides under the score HUD.
//
//                  Spawn handshake (3 cycles per attempt):
//                    S_IDLE : latch a valid candidate into spawn_x/y
//                    S_WAIT : snakes register their f_hit answers
//                    S_CHECK: commit if the cell is free, else retry
//////////////////////////////////////////////////////////////////////////////////

module Food_Manager #(parameter GRID_X = 100, GRID_Y = 75, MIN_Y = 3,
                      BONUS_PERIOD = 96,   // ticks between bonus spawns (~12 s)
                      BONUS_LIFE   = 40)(  // ticks a bonus stays up (~5 s)
    // Inputs
    input wire clk,
    input wire game_reset,                 // reset | welcome screen
    input wire tick,
    input wire playing,                    // state == PLAY
    input wire entropy,                    // any key/button press
    // Spawn free-cell handshake with both snakes
    output reg [$clog2(GRID_X)-1:0] spawn_x,
    output reg [$clog2(GRID_Y)-1:0] spawn_y,
    input wire f_hit1,
    input wire f_hit2,
    // Eat detection - candidate heads (stage-1 regs) from both snakes;
    // the eat_* outputs are registered here, i.e. stage-2 aligned
    input wire [$clog2(GRID_X)-1:0] s1_nx,
    input wire [$clog2(GRID_Y)-1:0] s1_ny,
    input wire [$clog2(GRID_X)-1:0] s2_nx,
    input wire [$clog2(GRID_Y)-1:0] s2_ny,
    output reg eat_norm1, eat_bonus1,
    output reg eat_norm2, eat_bonus2,
    // Consumption pulses back from the snakes (OR of both players)
    input wire ate_norm,
    input wire ate_bonus,
    // Render query - (x,y) from Pixel_Painter
    input wire [$clog2(GRID_X)-1:0] x,
    input wire [$clog2(GRID_Y)-1:0] y,
    output reg is_food,                    // registered
    output reg is_bonus,                   // registered
    // Status (testbench / debug)
    output reg food_alive,
    output reg bonus_alive
    );

    // free-running LFSR - position candidates
    reg [15:0] lfsr = 16'hABCD;
    always @(posedge clk)
        lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]^entropy};

    wire [6:0] cand_x = lfsr[6:0];
    wire [6:0] cand_y = lfsr[13:7];
    wire cand_valid = (cand_x < GRID_X) && (cand_y < GRID_Y) && (cand_y >= MIN_Y);

    // food positions
    reg [$clog2(GRID_X)-1:0] food_x,  bonus_x;
    reg [$clog2(GRID_Y)-1:0] food_y,  bonus_y;

    // spawner FSM
    localparam S_IDLE = 2'd0, S_WAIT = 2'd1, S_CHECK = 2'd2;
    reg [1:0] state;
    reg need_food, need_bonus;
    reg for_bonus;                          // what the current attempt is for

    reg [$clog2(BONUS_PERIOD+1)-1:0] bonus_timer;
    reg [$clog2(BONUS_LIFE+1)-1:0]   bonus_life;

    wire spawn_free = !f_hit1 && !f_hit2
                   && !(food_alive  && (spawn_x == food_x)  && (spawn_y == food_y))
                   && !(bonus_alive && (spawn_x == bonus_x) && (spawn_y == bonus_y));

    always @(posedge clk) begin
        if (game_reset) begin
            food_alive  <= 0;
            bonus_alive <= 0;
            need_food   <= 1;              // plant the first food immediately
            need_bonus  <= 0;
            bonus_timer <= 0;
            state       <= S_IDLE;
        end else begin
            // eaten -> gone (respawn / restart the bonus cycle)
            if (ate_norm) begin
                food_alive <= 0;
                need_food  <= 1;
            end
            if (ate_bonus) begin
                bonus_alive <= 0;
                bonus_timer <= 0;
            end

            // bonus lifecycle (counted in game ticks)
            if (tick && playing) begin
                if (bonus_alive) begin
                    bonus_life <= bonus_life - 1;
                    if (bonus_life == 1) begin  // expired
                        bonus_alive <= 0;
                        bonus_timer <= 0;
                    end
                end else if (!need_bonus) begin
                    bonus_timer <= bonus_timer + 1;
                    if (bonus_timer == BONUS_PERIOD - 1) begin
                        need_bonus  <= 1;
                        bonus_timer <= 0;
                    end
                end
            end

            // spawn handshake
            case (state)
                S_IDLE: begin
                    if ((need_food || need_bonus) && cand_valid) begin
                        spawn_x   <= cand_x[$clog2(GRID_X)-1:0];
                        spawn_y   <= cand_y[$clog2(GRID_Y)-1:0];
                        for_bonus <= !need_food;   // normal food first
                        state     <= S_WAIT;
                    end
                end
                S_WAIT: state <= S_CHECK;          // snakes register f_hit
                S_CHECK: begin
                    state <= S_IDLE;               // retry with a fresh draw if taken
                    if (spawn_free) begin
                        if (for_bonus) begin
                            bonus_x     <= spawn_x;
                            bonus_y     <= spawn_y;
                            bonus_alive <= 1;
                            bonus_life  <= BONUS_LIFE[$clog2(BONUS_LIFE+1)-1:0];
                            need_bonus  <= 0;
                        end else begin
                            food_x     <= spawn_x;
                            food_y     <= spawn_y;
                            food_alive <= 1;
                            need_food  <= 0;
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    // eat detection - candidate head vs food cells, registered (stage-2)
    always @(posedge clk) begin
        eat_norm1  <= food_alive  && (s1_nx == food_x)  && (s1_ny == food_y);
        eat_bonus1 <= bonus_alive && (s1_nx == bonus_x) && (s1_ny == bonus_y);
        eat_norm2  <= food_alive  && (s2_nx == food_x)  && (s2_ny == food_y);
        eat_bonus2 <= bonus_alive && (s2_nx == bonus_x) && (s2_ny == bonus_y);
    end

    // render read port - registered like every other pixel-path answer
    always @(posedge clk) begin
        is_food  <= food_alive  && (x == food_x)  && (y == food_y);
        is_bonus <= bonus_alive && (x == bonus_x) && (y == bonus_y);
    end

endmodule
