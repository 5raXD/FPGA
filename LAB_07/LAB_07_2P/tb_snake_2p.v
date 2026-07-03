`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     tb_snake_2p
// Project Name:    lab7_2p
// Description:     System testbench for the 2-player snake. Uses a fast
//                  game tick (TICK_MAX=2000 -> 20 us) and a fast bonus cycle
//                  so a whole game fits in ~2 ms of simulated time.
//
//                  Covered:
//                    1. reset -> IDLE, snakes parked at their spawns
//                    2. mode menu: default 1P, random key does not start,
//                       cursor to 2 PLAYERS, LEFT/RIGHT starts, mode latched
//                    3. P1 keyboard: opposite direction rejected
//                    4. REGRESSION for the same-tick double-turn reversal
//                       bug: P2 presses UP then RIGHT inside one tick window
//                       while committed LEFT; RIGHT must stay rejected
//                    5. eating forced food: +1 point, +1 length
//                    6. bonus food appears, forced eat: +3 points
//                    7. P1 driven into the top wall: crash1, GAME_OVER,
//                       winner = P2, survivor frozen, death tone triggered
//                    8. key press -> back to IDLE, scores cleared
//                    9. single player: numpad 1/2 select, Enter starts,
//                       P2 parked/invisible, no winner text, score2 = 0
//////////////////////////////////////////////////////////////////////////////////

module tb_snake_2p;

    reg clk = 0;
    reg rst = 0;
    reg btnU = 0, btnD = 0, btnL = 0, btnR = 0;
    reg PS2Clk = 1, PS2Data = 1;

    wire [3:0] vgaRed, vgaGreen, vgaBlue;
    wire Hsync, Vsync;
    wire [6:0] a_to_g;
    wire [3:0] an;
    wire dp, spk;

    // fast tick: 2000 * 10 ns = 20 us per game step
    snake_game_2p #(.TICK_MAX(2000), .BONUS_PERIOD(8), .BONUS_LIFE(5)) dut(
        .clk(clk), .rst(rst),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .PS2Clk(PS2Clk), .PS2Data(PS2Data),
        .vgaRed(vgaRed), .vgaGreen(vgaGreen), .vgaBlue(vgaBlue),
        .Hsync(Hsync), .Vsync(Vsync),
        .a_to_g(a_to_g), .an(an), .dp(dp), .spk(spk)
    );

    always #5 clk = ~clk;   // 100 MHz

    // grid_mapper states
    localparam ST_IDLE = 2'b00, ST_PLAY = 2'b01, ST_OVER = 2'b10;
    // directions
    localparam UP = 2'b00, DOWN = 2'b01, LEFT = 2'b10, RIGHT = 2'b11;

    integer errors = 0;
    task check(input cond, input [8*60:1] msg);
        begin
            if (cond) $display("PASS: %0s", msg);
            else begin
                errors = errors + 1;
                $display("FAIL: %0s   (t=%0t)", msg, $time);
            end
        end
    endtask

    // one PS/2 frame: start, 8 data bits LSB first, odd parity, stop.
    // 4 us per bit (the interface only counts falling edges).
    task ps2_frame(input [7:0] code);
        integer i;
        reg [10:0] frame;
        begin
            frame = {1'b1, ~(^code), code, 1'b0};
            for (i = 0; i < 11; i = i + 1) begin
                PS2Data = frame[i];
                #1000 PS2Clk = 0;
                #2000 PS2Clk = 1;
                #1000;
            end
            PS2Data = 1;
        end
    endtask

    // a full key tap like a real keyboard: make, then break (F0 + code).
    // Ps2_Interface re-arms is_valid only after the break, so make-only
    // streams (= holding a key, autorepeat) are correctly ignored.
    task ps2_send(input [7:0] code);
        begin
            ps2_frame(code);
            #2000;
            ps2_frame(8'hF0);
            #2000;
            ps2_frame(code);
            #2000;
        end
    endtask

    // hold a button for 1 us (> 64 clk the hysteresis debouncer needs)
    task press_u; begin btnU = 1; #1000 btnU = 0; end endtask
    task press_d; begin btnD = 1; #1000 btnD = 0; end endtask
    task press_l; begin btnL = 1; #1000 btnL = 0; end endtask
    task press_r; begin btnR = 1; #1000 btnR = 0; end endtask

    integer n;
    reg [6:0] hx, hy, p2x, p2y;
    reg [7:0] s_before;
    reg [6:0] l_before;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_snake_2p.vcd");
            $dumpvars(0, tb_snake_2p);
        end

        // ---- 1. reset -> IDLE --------------------------------------------
        #2000 rst = 1; #1500 rst = 0;
        #20000;
        check(dut.painter.grid_mapper.state == ST_IDLE, "reset -> IDLE screen");
        check(dut.snake_p1.body_x[0] == 25 && dut.snake_p1.body_y[0] == 37,
              "P1 parked at spawn (25,37)");
        check(dut.snake_p2.body_x[0] == 74 && dut.snake_p2.body_y[0] == 37,
              "P2 parked at spawn (74,37)");

        // ---- 2. menu: pick "2 PLAYERS", start; heads move -----------------
        check(dut.sel_2p == 0, "menu defaults to 1 PLAYER");
        ps2_send(8'h1C);    // 'A': not a menu key - must NOT start the game
        #5000;
        check(dut.painter.grid_mapper.state == ST_IDLE, "random key does not start");
        press_d;            // cursor down -> "2 PLAYERS"
        #3000;
        check(dut.sel_2p == 1, "cursor moves to 2 PLAYERS");
        press_r;            // confirm (LEFT/RIGHT or Enter starts)
        #3000;
        check(dut.painter.grid_mapper.state == ST_PLAY, "start press -> PLAY");
        check(dut.mode_2p == 1, "mode latched: 2 players");

        hx  = dut.snake_p1.body_x[0];
        p2x = dut.snake_p2.body_x[0];
        repeat (3) @(posedge dut.tick);
        #100;
        check(dut.snake_p1.body_x[0] == hx + 3,  "P1 moves RIGHT (3 ticks)");
        check(dut.snake_p2.body_x[0] == p2x - 3, "P2 moves LEFT (3 ticks)");

        // ---- 3. P1: direct reversal rejected -----------------------------
        ps2_send(8'h6B);    // LEFT while committed RIGHT
        #5000;
        check(dut.dir1 == RIGHT, "P1 LEFT rejected while moving RIGHT");
        ps2_send(8'h75);    // UP - legal turn, P1 starts climbing
        #5000;
        check(dut.dir1 == UP, "P1 UP accepted");

        // ---- 4. P2: same-tick double-turn regression ---------------------
        // committed LEFT; press UP then RIGHT inside ONE tick window.
        // Buggy check-against-dir would accept RIGHT (reversal of LEFT).
        @(posedge dut.tick); #200;
        press_u;            // pulse ~0.7 us after press
        #500;
        press_r;
        #3000;
        check(dut.dir2 == UP, "P2 double-turn: RIGHT still rejected (bugfix)");
        repeat (2) @(posedge dut.tick); #100;
        check(dut.crash2 == 0, "P2 alive after double-turn attempt");
        // steer P2 back LEFT (legal vs committed UP) so it stays clear
        press_l;
        #3000;
        check(dut.dir2 == LEFT, "P2 back to LEFT");

        // ---- 5. forced food eat: +1 point, +1 length ----------------------
        @(posedge dut.tick); #100;
        hx = dut.snake_p1.body_x[0];
        hy = dut.snake_p1.body_y[0];       // P1 climbing: next cell (hx, hy-1)
        force dut.foods.food_x = hx;
        force dut.foods.food_y = hy - 7'd1;
        s_before = dut.score1;
        l_before = dut.len1;
        repeat (2) @(posedge dut.tick); #100;
        check(dut.score1 >= s_before + 1, "P1 ate food: score +1");
        check(dut.len1   == l_before + 1, "P1 ate food: length +1");
        release dut.foods.food_x;
        release dut.foods.food_y;

        // ---- 6. bonus food: appears, forced eat +3 ------------------------
        n = 0;
        while (!dut.bonus_alive && n < 20) begin
            @(posedge dut.tick); n = n + 1;
        end
        check(dut.bonus_alive == 1, "bonus food spawned");
        @(posedge dut.tick); #100;
        hx = dut.snake_p1.body_x[0];
        hy = dut.snake_p1.body_y[0];
        force dut.foods.bonus_x = hx;
        force dut.foods.bonus_y = hy - 7'd1;
        s_before = dut.score1;
        repeat (2) @(posedge dut.tick); #100;
        check(dut.score1 >= s_before + 3, "P1 ate bonus: score +3");
        release dut.foods.bonus_x;
        release dut.foods.bonus_y;

        // ---- 7. P1 into the top wall: crash, winner, freeze, sound -------
        n = 0;
        while (!dut.crash1 && n < 60) begin
            @(posedge dut.tick); n = n + 1;
        end
        check(dut.crash1 == 1, "P1 crashed into the top wall");
        #50;
        check(dut.painter.grid_mapper.state == ST_OVER, "state -> GAME_OVER");
        check(dut.winner == 2'b10, "winner = P2");
        check(dut.crash2 == 0, "P2 did not crash");
        check(dut.sfx.dur != 0, "death tone playing");
        p2x = dut.snake_p2.body_x[0];
        p2y = dut.snake_p2.body_y[0];
        repeat (3) @(posedge dut.tick); #100;
        check(dut.snake_p2.body_x[0] == p2x && dut.snake_p2.body_y[0] == p2y,
              "survivor frozen on GAME_OVER");

        // ---- 8. key -> IDLE, scores cleared -------------------------------
        ps2_send(8'h1C);
        #5000;
        check(dut.painter.grid_mapper.state == ST_IDLE, "key press -> IDLE");
        #1000;
        check(dut.score1 == 0 && dut.score2 == 0, "scores cleared in IDLE");

        // ---- 9. single-player mode -----------------------------------------
        ps2_send(8'h69); #3000;
        check(dut.sel_2p == 0, "numpad 1 -> cursor 1 PLAYER");
        ps2_send(8'h72); #3000;
        check(dut.sel_2p == 1, "numpad 2 -> cursor 2 PLAYERS");
        ps2_send(8'h69); #3000;
        check(dut.sel_2p == 0, "numpad 1 -> cursor back to 1 PLAYER");
        ps2_send(8'h5A);    // Enter = start
        #5000;
        check(dut.painter.grid_mapper.state == ST_PLAY, "enter starts the game");
        check(dut.mode_2p == 0, "mode latched: single player");
        hx = dut.snake_p1.body_x[0];
        repeat (3) @(posedge dut.tick); #100;
        check(dut.snake_p1.body_x[0] == hx + 3, "1P: P1 moving");
        check(dut.snake_p2.body_x[0] == 74 && dut.snake_p2.body_y[0] == 37,
              "1P: P2 parked (held in reset)");
        ps2_send(8'h75);    // UP - climb into the top wall
        n = 0;
        while (!dut.crash1 && n < 60) begin
            @(posedge dut.tick); n = n + 1;
        end
        check(dut.crash1 == 1, "1P: P1 crashed");
        #50;
        check(dut.painter.grid_mapper.state == ST_OVER, "1P: GAME_OVER screen");
        check(dut.painter.hud.show_winner == 0, "1P: winner text suppressed");
        check(dut.score2 == 0, "1P: P2 score stayed 0");

        // ---- summary ------------------------------------------------------
        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $finish;
    end

    // global watchdog
    initial begin
        #8_000_000; // 8 ms
        $display("WATCHDOG TIMEOUT");
        $finish;
    end

endmodule
