`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Saleh Khalil, Mahmood Stitia
// Module:    snake_game (top)   (after_C_debug)
//
// Adds a top-level game_FSM:
//   * power-up / reset (btnC) -> IDLE  -> shows welcome.mem ("PRESS ENTER")
//   * Enter key               -> PLAY  -> the game
//   * crash                   -> GAME_OVER -> shows skull.mem
//   * Enter again             -> IDLE
// The Snake is held in reset whenever we are not in PLAY, so every game starts
// fresh (this is what makes restart work). See changes.html.
//////////////////////////////////////////////////////////////////////////////////

module snake_game(
    // Inputs
    input  wire clk,   // W5  - 100 MHz system clock
    input  wire rst,   // U18 - btnC, active high (pressed = 1)
    // Inputs - from PS2 keyboard
    input  wire PS2Clk,  // C17 - keyboard clock
    input  wire PS2Data, // B17 - keyboard data
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

    localparam ENTER_CODE = 8'h5A; // PS/2 scancode for Enter

    // FSM states (must match game_FSM)
    localparam PLAY = 2'b01;

    wire [7:0]  scancode;
    wire        keyPressed;
    wire [1:0]  dir;
    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;
    wire        reset;
    wire [15:0] score;
    wire        tick;
    wire [$clog2(GRID_X)-1:0] x;
    wire [$clog2(GRID_Y)-1:0] y;
    wire on_snake;
    wire is_head;
    wire is_food;
    wire crash;
    wire [1:0] game_state;

    // "Enter pressed" pulse, and "hold snake in reset unless we are playing"
    wire enter     = keyPressed && (scancode == ENTER_CODE);
    wire snake_rst = reset || (game_state != PLAY);

    ///////////////////////
    ///  IO - External  ///
    ///////////////////////

    Debouncer debouncer(
        .clk(clk),
        .input_unstable(rst),
        .output_stable(reset)
    );

    Seg_7_Display seg_7_display(
        .x(score),
        .clk(clk),
        .clr(reset),
        .a_to_g(a_to_g),
        .an(an),
        .dp(dp)
    );

    Ps2_Interface ps2_interface(
        .PS2Clk(PS2Clk),
        .rstn(~reset),
        .PS2Data(PS2Data),
        .scancode(scancode),
        .keyPressed(keyPressed)
    );

    VGA_Interface vga_interface(
        .clk(clk),
        .rstn(~reset),
        .pixel_color(pixel_color),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .XCoord(XCoord),
        .YCoord(YCoord)
    );

    ////////////////
    //  Internal  //
    ////////////////

    // Game state machine
    game_FSM game_fsm(
        .clk(clk),
        .reset(reset),
        .enter(enter),
        .crash(crash),
        .state(game_state)
    );

    // Image Processing - Screen
    Pixel_Painter #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) painter(
        .game_state(game_state),
        .is_food(is_food),
        .on_snake(on_snake),
        .is_head(is_head),
        .XCoord(XCoord),
        .YCoord(YCoord),
        .x(x),
        .y(y),
        .pixel_color(pixel_color)
    );

    // Navigation System - Keyboard
    Navigation_System navigation_system(
        .clk(clk),
        .reset(reset),
        .scancode(scancode),
        .keyPressed(keyPressed),
        .dir(dir)
    );

    Snake #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) snake(
        .clk(clk),
        .reset(snake_rst),      // fresh snake unless we are in PLAY
        .tick(tick),
        .dir(dir),
        .keyPressed(keyPressed),
        .x(x),
        .y(y),
        .on_snake(on_snake),
        .is_head(is_head),
        .is_food(is_food),
        .crash(crash),
        .score(score)
    );

    // Game Tick - Clock Divider (7 Hz tick for 100 MHz clock)
    Game_Tick #(.TICK_MAX(14285714)) game_tick(
        .clk(clk),
        .reset(reset),
        .tick(tick)
    );

endmodule
