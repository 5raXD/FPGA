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
    output wire [6:0] a_to_g,        // 7-segment cathodes
    output wire [3:0] an,         // 7-segment anodes
    output wire       dp         // decimal point
    );

    wire [7:0] scancode;
    wire keyPressed;
    wire [1:0] dir;
    wire [10:0] XCoord;
    wire [10:0] YCoord;
    wire [11:0] pixel_color;
    wire reset;
    wire [15:0] score;
    wire tick;

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

    Pixel_Painter painter(
        // Inputs
        .clk(clk),
        .reset(reset),
        .keyPressed(keyPressed),
        .XCoord(XCoord),
        .YCoord(YCoord),
        .tick(tick),
        // .dir(dir),
        // Outputs
        .pixel_color(pixel_color)
    );

    Navigation_System navigation_system(
        // Inputs
        .clk(clk),
        .reset(reset),
        .scancode(scancode),
        .keyPressed(keyPressed),
        // Outputs
        .dir(dir)
    );

    Game_Tick game_tick(
        // Inputs
        .clk(clk),
        .reset(reset),
        // Outputs
        .tick(tick)
    );

endmodule