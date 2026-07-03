`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     snake_game_2p
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Two-player Snake. Player 1 (yellow/gray) drives with the
//                  keyboard (numpad 4/6/8/5), player 2 (cyan/blue) with the
//                  board push buttons (btnU/D/L/R). Shared field, shared
//                  food + timed bonus food (+3), first to crash loses.
//                  Score on the 7-seg (P1 left pair, P2 right pair, decimal)
//                  and as a pixel-font HUD on the VGA. Sound FX on Pmod JA1.
//////////////////////////////////////////////////////////////////////////////////

module snake_game_2p #(
    parameter TICK_MAX     = 12_500_000,  // 8 Hz game step at 100 MHz
    parameter BONUS_PERIOD = 96,          // ticks between bonus spawns (~12 s)
    parameter BONUS_LIFE   = 40           // ticks a bonus stays up (~5 s)
    )(
    // Inputs
    input  wire clk,   // W5  - 100 MHz system clock
    input  wire rst,   // U18 - btnC, active high (pressed = 1)
    // Inputs - player 2 direction buttons
    input  wire btnU,  // T18
    input  wire btnD,  // U17
    input  wire btnL,  // W19
    input  wire btnR,  // T17
    // Inputs - from PS2 keyboard (player 1)
    input  wire PS2Clk,  // C17 - keyboard clock
    input  wire PS2Data, // B17 - keyboard data
    // Outputs
    // Outputs - to VGA pins
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync,
    // Outputs - to 7-segment display
    output wire [6:0] a_to_g,
    output wire [3:0] an,
    output wire       dp,
    // Outputs - sound (Pmod JA1: passive buzzer to GND)
    output wire spk
    );

    parameter GRID_X = 100;
    parameter GRID_Y = 75;
    localparam XW = $clog2(GRID_X);
    localparam YW = $clog2(GRID_Y);

    wire [7:0] scancode;
    wire keyPressed_ps2;   // raw, PS2Clk domain
    wire keyPressed;       // synchronized 1-clk pulse, clk domain
    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;
    wire reset;
    wire tick;
    wire [XW-1:0] x;
    wire [YW-1:0] y;
    wire game_idle, game_over;

    // While the welcome screen is shown, hold the snakes (and the direction
    // registers) in reset so every game starts fresh. During GAME_OVER
    // nothing is reset, so the scores stay displayed.
    wire game_reset = reset | game_idle;

    ///////////////////////
    ///  IO - External  ///
    ///////////////////////

    Debouncer debouncer(
        // Inputs
        .clk(clk),
        .input_unstable(rst),
        // Outputs
        .output_stable(reset)
    );

    // player 2 buttons -> 1-clk pulses (same hysteresis debouncer as rst)
    wire p2_up, p2_down, p2_left, p2_right;
    Debouncer deb_u(.clk(clk), .input_unstable(btnU), .output_stable(p2_up));
    Debouncer deb_d(.clk(clk), .input_unstable(btnD), .output_stable(p2_down));
    Debouncer deb_l(.clk(clk), .input_unstable(btnL), .output_stable(p2_left));
    Debouncer deb_r(.clk(clk), .input_unstable(btnR), .output_stable(p2_right));

    Ps2_Interface ps2_interface(
        // Inputs
        .PS2Clk(PS2Clk),
        .rstn(~reset),
        .PS2Data(PS2Data),
        // Outputs
        .scancode(scancode),
        .keyPressed(keyPressed_ps2)
    );

    // Clock domain crossing: keyPressed_ps2 is generated on PS2Clk (~15 kHz)
    // and stays high for a full PS2 clock (~60 us = thousands of clk cycles).
    // Two flip-flops synchronize it into the clk domain, the third stage
    // turns it into a single-cycle pulse (otherwise the GridMapper FSM would
    // race GAME_OVER -> IDLE -> PLAY on one keypress). scancode is stable
    // long before the pulse comes out, so it is safe to sample with it.
    reg [2:0] kp_sync = 3'b000;
    always @(posedge clk) kp_sync <= {kp_sync[1:0], keyPressed_ps2};
    assign keyPressed = kp_sync[1] & ~kp_sync[2];

    // "any key" leaves the game-over screen; buttons work too
    wire any_press = keyPressed | p2_up | p2_down | p2_left | p2_right;

    // player 1 keyboard requests (numpad 4/6/8/5 make codes)
    wire p1_up    = keyPressed && (scancode == 8'h75);
    wire p1_down  = keyPressed && (scancode == 8'h73);
    wire p1_left  = keyPressed && (scancode == 8'h6B);
    wire p1_right = keyPressed && (scancode == 8'h74);

    ///////////////////////////////
    //  Mode menu (1P / 2P pick) //
    ///////////////////////////////
    // On the welcome screen: UP/DOWN (either input) or numpad 1/2 move the
    // cursor between "1 PLAYER" and "2 PLAYERS"; LEFT/RIGHT or Enter starts.
    // The choice is latched into mode_2p for the whole game.
    wire sel1_key = keyPressed && (scancode == 8'h69);   // numpad 1
    wire sel2_key = keyPressed && (scancode == 8'h72);   // numpad 2
    wire enter_key = keyPressed && (scancode == 8'h5A);  // enter
    wire start_press = p1_left | p1_right | p2_left | p2_right | enter_key;

    reg sel_2p  = 0;   // menu cursor (0 = 1 PLAYER)
    reg mode_2p = 0;   // latched when the game starts
    always @(posedge clk) begin
        if (reset) begin
            sel_2p  <= 0;
            mode_2p <= 0;
        end else if (game_idle) begin
            if      (p1_up   | p2_up   | sel1_key) sel_2p <= 0;
            else if (p1_down | p2_down | sel2_key) sel_2p <= 1;
            if (start_press) mode_2p <= sel_2p;
        end
    end

    VGA_Interface vga_interface(
        // Inputs
        .clk(clk),
        .rstn(~reset),
        .pixel_color(pixel_color),
        // Outputs - to VGA pins
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue),
        .Hsync(Hsync),
        .Vsync(Vsync),
        // Outputs - to Renderer
        .XCoord(XCoord),
        .YCoord(YCoord)
    );

    ////////////////
    //  Internal  //
    ////////////////

    // direction control - one per player, with the committed-direction
    // no-reversal rule (see Direction_Ctrl.v)
    wire [1:0] dir1, dir2;
    Direction_Ctrl #(.START_DIR(2'b11)) nav_p1( // P1 starts moving RIGHT
        .clk(clk), .reset(game_reset), .tick(tick),
        .req_up(p1_up), .req_down(p1_down),
        .req_left(p1_left), .req_right(p1_right),
        .dir(dir1)
    );
    Direction_Ctrl #(.START_DIR(2'b10)) nav_p2( // P2 starts moving LEFT
        .clk(clk), .reset(game_reset | ~mode_2p), .tick(tick),
        .req_up(p2_up), .req_down(p2_down),
        .req_left(p2_left), .req_right(p2_right),
        .dir(dir2)
    );

    // snakes - P1 spawns on the left facing right, P2 on the right facing left
    wire [XW-1:0] s1_nx, s2_nx;
    wire [YW-1:0] s1_ny, s2_ny;
    wire q_hit1, q_hit2;         // q_hitN = "the other's candidate head is inside snake N"
    wire f_hit1, f_hit2;
    wire crash1, crash2;
    wire on_snake1, is_head1, on_snake2, is_head2;
    wire ate_norm1, ate_bonus1, ate_norm2, ate_bonus2;
    wire eat_norm1, eat_bonus1, eat_norm2, eat_bonus2;
    wire [6:0] len1, len2;
    wire [XW-1:0] spawn_x;
    wire [YW-1:0] spawn_y;

    // head-to-head: both candidate heads on the same cell -> both crash (draw)
    reg hh_r;
    always @(posedge clk)
        hh_r <= (s1_nx == s2_nx) && (s1_ny == s2_ny);

    // in single-player mode P2 does not exist: no cross collisions
    wire hit_other1 = (q_hit2 | hh_r) & mode_2p; // P1 runs into P2 / head-to-head
    wire hit_other2 = (q_hit1 | hh_r) & mode_2p; // P2 runs into P1 / head-to-head

    Snake #(.GRID_X(GRID_X), .GRID_Y(GRID_Y),
            .START_X(25), .START_Y(37)) snake_p1(
        .clk(clk), .reset(game_reset), .tick(tick), .freeze(game_over),
        .dir(dir1),
        .eat_norm(eat_norm1), .eat_bonus(eat_bonus1),
        .hit_other(hit_other1),
        .qx(s2_nx), .qy(s2_ny), .q_hit(q_hit1),
        .fx(spawn_x), .fy(spawn_y), .f_hit(f_hit1),
        .x(x), .y(y), .on_snake(on_snake1), .is_head(is_head1),
        .next_x_r(s1_nx), .next_y_r(s1_ny),
        .crash(crash1),
        .ate_norm(ate_norm1), .ate_bonus(ate_bonus1),
        .length_o(len1)
    );

    Snake #(.GRID_X(GRID_X), .GRID_Y(GRID_Y),
            .START_X(74), .START_Y(37)) snake_p2(
        // held in reset in single-player mode - P2 does not exist
        .clk(clk), .reset(game_reset | ~mode_2p), .tick(tick), .freeze(game_over),
        .dir(dir2),
        .eat_norm(eat_norm2), .eat_bonus(eat_bonus2),
        .hit_other(hit_other2),
        .qx(s1_nx), .qy(s1_ny), .q_hit(q_hit2),
        .fx(spawn_x), .fy(spawn_y), .f_hit(f_hit2),
        .x(x), .y(y), .on_snake(on_snake2), .is_head(is_head2),
        .next_x_r(s2_nx), .next_y_r(s2_ny),
        .crash(crash2),
        .ate_norm(ate_norm2), .ate_bonus(ate_bonus2),
        .length_o(len2)
    );

    // food - shared field, normal + timed bonus
    wire is_food, is_bonus;
    wire food_alive, bonus_alive;
    Food_Manager #(.GRID_X(GRID_X), .GRID_Y(GRID_Y), .MIN_Y(3),
                   .BONUS_PERIOD(BONUS_PERIOD), .BONUS_LIFE(BONUS_LIFE)) foods(
        .clk(clk), .game_reset(game_reset), .tick(tick),
        .playing(~game_idle & ~game_over),
        .entropy(any_press),
        .spawn_x(spawn_x), .spawn_y(spawn_y),
        .f_hit1(f_hit1), .f_hit2(f_hit2 & mode_2p), // P2 cells are free in 1P
        .s1_nx(s1_nx), .s1_ny(s1_ny), .s2_nx(s2_nx), .s2_ny(s2_ny),
        .eat_norm1(eat_norm1), .eat_bonus1(eat_bonus1),
        .eat_norm2(eat_norm2), .eat_bonus2(eat_bonus2),
        .ate_norm(ate_norm1 | ate_norm2),
        .ate_bonus(ate_bonus1 | ate_bonus2),
        .x(x), .y(y), .is_food(is_food), .is_bonus(is_bonus),
        .food_alive(food_alive), .bonus_alive(bonus_alive)
    );

    // scores - normal food +1, bonus food +3 (growth is +1 either way)
    reg [7:0] score1, score2;
    always @(posedge clk) begin
        if (game_reset) begin
            score1 <= 0;
            score2 <= 0;
        end else begin
            if (ate_norm1)  score1 <= score1 + 8'd1;
            if (ate_bonus1) score1 <= score1 + 8'd3;
            if (ate_norm2)  score2 <= score2 + 8'd1;
            if (ate_bonus2) score2 <= score2 + 8'd3;
        end
    end

    // winner - latched on the first crash. Both crash on the same tick
    // (e.g. head-to-head) -> draw.
    reg [1:0] winner;   // 00 draw, 01 P1 wins, 10 P2 wins
    reg won;
    always @(posedge clk) begin
        if (game_reset) begin
            winner <= 2'b00;
            won    <= 1'b0;
        end else if (!won && (crash1 || crash2)) begin
            won    <= 1'b1;
            winner <= (crash1 && crash2) ? 2'b00 :
                       crash1            ? 2'b10 : 2'b01;
        end
    end

    // binary -> BCD for the displays (scores capped at 99 for display)
    wire [7:0] s1_cap = (score1 > 8'd99) ? 8'd99 : score1;
    wire [7:0] s2_cap = (score2 > 8'd99) ? 8'd99 : score2;
    wire [3:0] p1_tens = s1_cap / 10;
    wire [3:0] p1_ones = s1_cap % 10;
    wire [3:0] p2_tens = s2_cap / 10;
    wire [3:0] p2_ones = s2_cap % 10;

    // 7-seg: [P1 tens][P1 ones][P2 tens][P2 ones], the dot after digit 2
    // separates the players. Single player: right pair blanked (code 'hB
    // renders all segments off in Seg_7_Display).
    Seg_7_Display seg_7_display(
        // Inputs
        .x(mode_2p ? {p1_tens, p1_ones, p2_tens, p2_ones}
                   : {p1_tens, p1_ones, 4'hB,    4'hB   }),
        .clk(clk),
        .clr(reset),
        // Outputs
        .a_to_g(a_to_g),
        .an(an),
        .dp(dp)
    );

    // Image Processing - Screen
    Pixel_Painter #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) painter(
        // Inputs
        .clk(clk),
        .reset(reset),
        .start_press(start_press),
        .key_any(any_press),
        .sel_2p(sel_2p),
        .mode_2p(mode_2p),
        .crash(crash1 | crash2),
        .is_food(is_food),
        .is_bonus(is_bonus),
        .on_snake1(on_snake1),
        .is_head1(is_head1),
        .on_snake2(on_snake2 & mode_2p),  // P2 invisible in single player
        .is_head2(is_head2 & mode_2p),
        .winner(winner),
        .p1_tens(p1_tens), .p1_ones(p1_ones),
        .p2_tens(p2_tens), .p2_ones(p2_ones),
        .XCoord(XCoord),
        .YCoord(YCoord),
        // Outputs
        .x(x),
        .y(y),
        .game_idle(game_idle),
        .game_over(game_over),
        .pixel_color(pixel_color)
    );

    // sound effects - eat blip, bonus chirp, death tone
    reg game_over_d;
    always @(posedge clk) game_over_d <= game_over;
    wire trig_death = game_over & ~game_over_d;

    Sound_FX sfx(
        .clk(clk), .reset(reset),
        .trig_eat(ate_norm1 | ate_norm2),
        .trig_bonus(ate_bonus1 | ate_bonus2),
        .trig_death(trig_death),
        .spk(spk)
    );

    // Game Tick - Clock Divider
    Game_Tick #(.TICK_MAX(TICK_MAX)) game_tick(
        // Inputs
        .clk(clk),
        .reset(reset),
        // Outputs
        .tick(tick)
    );

endmodule
