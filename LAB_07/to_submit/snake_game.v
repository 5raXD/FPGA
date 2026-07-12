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
    parameter TICK_MAX = 14_285_714; // 7Hz tick for 100MHz clock

    wire [7:0] scancode;
    wire keyPressed;
    wire [1:0] dir;
    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;
    wire reset;
    wire [15:0] score;
    wire [15:0] length;
    wire tick;
    wire [$clog2(GRID_X)-1:0] x;
    wire [$clog2(GRID_Y)-1:0] y;
    // Snake grid owner - shared signals
    wire [$clog2(GRID_X)-1:0] food_x;
    wire [$clog2(GRID_Y)-1:0] food_y;
    wire on_snake;
    wire is_head;
    wire is_food;
    wire food_on_snake;
    wire crash;
    wire start_game;
    // ENTER key (PS/2 make-code 0x5A) - the only key that restarts after game over
    wire enter = keyPressed && (scancode == 8'h5A);

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
        .keyPressed(keyPressed)
    );

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
        .XCoord(XCoord),
        .YCoord(YCoord),
        .tick(tick),
        .crash(crash),
        .is_food(is_food),
        .on_snake(on_snake),
        .is_head(is_head),
        .score(score),
        .enter(enter),
        // .dir(dir),
        // Outputs
        .x(x),
        .y(y),
        .pixel_color(pixel_color),
        .start_game(start_game)
    );

    // Navigation System - Keyboard
    Navigation_System navigation_system(
        // Inputs
        .clk(clk),
        .reset(reset),
        .scancode(scancode),
        .keyPressed(keyPressed),
        // Outputs
        .dir(dir)
    );

    Snake #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) snake(
        // Inputs
        .clk(clk),
        .reset(reset | ~start_game),
        .tick(tick),
        .dir(dir),
        .keyPressed(keyPressed),
        // Inputs - food location (from farmer)
        // .food_x(food_x),
        // .food_y(food_y),
        // Inputs - pixel being scanned (read address from the renderer)
        .x(x),
        .y(y),
        // Outputs - grid reads (to Pixel_Painter / GridMapper)
        .on_snake(on_snake),
        .is_head(is_head),
        .is_food(is_food),
        // Outputs - food cell occupancy (to farmer, so food avoids the body)
        //.food_on_snake(food_on_snake),
        // Outputs - game status
        .crash(crash),
        .length(length),
        .score(score)
    );

    // Game Tick - Clock Divider
    Game_Tick #(.TICK_MAX(TICK_MAX)) game_tick( // 7Hz tick for 100MHz clock
        // Inputs
        .clk(clk),
        .reset(reset),
        .score(length),
        // Outputs
        .tick(tick)
    );

endmodule
