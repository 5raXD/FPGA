`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Full-game testbench for snake_game.
// Drives clk / rst / PS2 keyboard and walks the game through IDLE -> PLAY -> GAME_OVER
//////////////////////////////////////////////////////////////////////////////////

module snake_game_tb();

    localparam PS2_HALF = 100;

    // Scancodes (see Navigation_System.v)
    localparam LEFT_KEY = 8'h6B;
    localparam RIGHT_KEY = 8'h74;
    localparam UP_KEY = 8'h75;
    localparam DOWN_KEY = 8'h73;
    localparam ZERO_KEY = 8'h70; // zero key
    reg clk;
    reg rst;
    reg PS2Clk;
    reg PS2Data;

    wire [3:0] vgaRed, vgaGreen, vgaBlue;
    wire Hsync, Vsync;
    wire [6:0] a_to_g;
    wire [3:0] an;
    wire dp;

    snake_game #(.TICK_MAX(500)) dut(
        // inputs
        .clk(clk),
        .rst(rst),
        .PS2Clk(PS2Clk),
        .PS2Data(PS2Data),
        // outputs
        // Outputs - to VGA pins
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue),
        .Hsync(Hsync),
        .Vsync(Vsync),
        // Outputs - to 7-segment display
        .a_to_g(a_to_g),
        .an(an),
        .dp(dp)
    );

    always #5 clk = ~clk; // 100MHz clk

    // ---- PS/2 device -> host frame ----
    task ps2_bit(input v);
        begin
            PS2Data = v;
            #PS2_HALF PS2Clk = 1'b0; // sampled on this falling edge
            #PS2_HALF PS2Clk = 1'b1;
        end
    endtask

    task ps2_send_byte(input [7:0] b);
        integer i;
        begin
            ps2_bit(1'b0);                       // start
            for (i = 0; i < 8; i = i + 1)
                ps2_bit(b[i]);                   // 8 data bits, LSB first
            ps2_bit(~(^b));                      // odd parity
            ps2_bit(1'b1);                       // stop
            PS2Data = 1'b1;                      // idle high
        end
    endtask

    // One key tap = make code, then break (F0 + code) so the interface re-arms.
    task ps2_tap(input [7:0] code);
        begin
            ps2_send_byte(code);
            ps2_send_byte(8'hF0);
            ps2_send_byte(code);
        end
    endtask

    task pulse_reset;
        begin
            // The debouncer counter powers up as X in sim (no FPGA global reset),
            // so its reset pulse never resolves. Drive the reset net directly.
            rst = 1'b0;
            force dut.reset = 1'b1;
            repeat (4) @(posedge clk);
            force dut.reset = 1'b0; // stays deasserted (forced) for the rest of the run
        end
    endtask

    reg go_x;
    reg go_y;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("snake_game_tb.vcd");
            $dumpvars(0, snake_game_tb);
        end

        clk = 0; 
        rst = 0; 
        PS2Clk = 1; 
        PS2Data = 1;
        go_x = 0;
        go_y = 0;

        pulse_reset;
        repeat (50) @(posedge clk);

        // Scenario 1: snake crashes into wall

        ps2_tap(ZERO_KEY);   // IDLE -> PLAY, snake starts moving RIGHT
        #40_000;              // let it run a few ticks

        ps2_tap(UP_KEY);     // change direction to UP
        repeat (5) #40_000;              // let it run a few ticks


        // Scenario 2: eat one bite of food and die
        ps2_tap(UP_KEY);     // change direction to UP
        repeat (2) #40_000;
        
        go_x = (dut.snake.plant_x <= dut.snake.head_x)? 1'b0 : 1'b1; // 1 = move right, 0 = move left
        go_y = (dut.snake.plant_y <= dut.snake.head_y)? 1'b0 : 1'b1; // 1 = move down, 0 = move up

        if(go_x) ps2_tap(RIGHT_KEY);
        else ps2_tap(UP_KEY);
        wait(dut.snake.plant_x == dut.snake.head_x);

        if(go_y) ps2_tap(DOWN_KEY);
        else ps2_tap(UP_KEY);
        wait(dut.snake.plant_y == dut.snake.head_y);

        repeat (5) #40_000; // let it run a few ticks


        $finish;
    end

    // Log one line per tick.
    always @(posedge dut.tick) begin
        $display("t=%0t play=%b dir=%b head=(%0d,%0d) len=%0d crash=%b state=%0d",
            $time, dut.start_game, dut.dir,
            dut.snake.head_x, dut.snake.head_y,
            dut.snake.length, dut.crash,
            dut.painter.grid_mapper.state);
    end

    // Safety timeout
    initial begin
        #100_000_000;
        $display("timeout");
        $finish;
    end

endmodule
