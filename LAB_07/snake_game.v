`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module snake_game(
    // Inputs
    input  wire clk,   // W5  - 100 MHz system clock
    input  wire rst,   // U18 - btnC, active high (pressed = 1)
    // Inputs - from PS2 keyboard
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
    output wire       dp
    );

    parameter GRID_X = 100;
    parameter GRID_Y = 75;

    wire [7:0] scancode;
    wire keyPressed_ps2;   // raw, PS2Clk domain
    wire keyPressed;       // synchronized 1-clk pulse, clk domain
    wire [1:0] dir;
    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;
    wire reset;
    wire [15:0] score;
    wire tick;
    wire [$clog2(GRID_X)-1:0] x;
    wire [$clog2(GRID_Y)-1:0] y;
    // Snake grid queries - shared signals
    wire on_snake;
    wire is_head;
    wire is_food;
    wire crash;
    wire game_idle;

    // While the welcome screen is shown, hold the snake (and the direction
    // register) in reset so every game starts fresh from the center, moving
    // right. During GAME_OVER nothing is reset, so the score stays displayed.
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

    Seg_7_Display seg_7_display(
        // Inputs
        .x(score),
        .clk(clk),
        .clr(reset),
        // Outputs
        .a_to_g(a_to_g),
        .an(an),
        .dp(dp)
	);

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

    // Image Processing - Screen
    Pixel_Painter #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) painter(
        // Inputs
        .clk(clk),
        .reset(reset),
        .keyPressed(keyPressed),
        .crash(crash),
        .is_food(is_food),
        .on_snake(on_snake),
        .is_head(is_head),
        .XCoord(XCoord),
        .YCoord(YCoord),
        .tick(tick),
        // Outputs
        .x(x),
        .y(y),
        .game_idle(game_idle),
        .pixel_color(pixel_color)
    );

    // Navigation System - Keyboard
    Navigation_System navigation_system(
        // Inputs
        .clk(clk),
        .reset(game_reset),
        .scancode(scancode),
        .keyPressed(keyPressed),
        // Outputs
        .dir(dir)
    );

    Snake #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) snake(
        // Inputs
        .clk(clk),
        .reset(game_reset),
        .tick(tick),
        .dir(dir),
        .keyPressed(keyPressed), // entropy for the food LFSR
        // Inputs - pixel being scanned (read address from the renderer)
        .x(x),
        .y(y),
        // Outputs - grid reads (to Pixel_Painter / GridMapper)
        .on_snake(on_snake),
        .is_head(is_head),
        .is_food(is_food),
        // Outputs - game status
        .crash(crash),
        .score(score)
    );

    // Game Tick - Clock Divider
    Game_Tick #(.TICK_MAX(12_500_000)) game_tick( // 8Hz tick for 100MHz clock
        // Inputs
        .clk(clk),
        .reset(reset),
        // Outputs
        .tick(tick)
    );

endmodule
