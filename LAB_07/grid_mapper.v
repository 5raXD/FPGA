`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire keyPressed,
    input  wire [$clog2(GRID_X)-1:0] x,   // grid cell (XCoord>>3) - gameplay
    input  wire [$clog2(GRID_Y)-1:0] y,
    input  wire [8:0] sx,                 // hires pixel (XCoord>>2) - screens
    input  wire [8:0] sy,                 // hires pixel (YCoord>>2) - screens
    input wire crash,
    input wire is_food,
    input wire on_snake,
    input wire is_head,
    // Outputs
    output wire grid_enable,
    output wire in_idle,                  // hold the snake in reset on the welcome screen
    output reg  [11:0] block_color
    );

    // FSM states
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam BLACK            = 12'h000;
    localparam GREEN            = 12'h0F0;
    localparam FOOD_COLOR       = 12'hF11;
    localparam SNAKE_COLOR      = 12'h333;
    localparam SNAKE_HEAD_COLOR = 12'hFD0; // unique head color - warm yellow
    localparam WELCOME_FG       = 12'h3D9; // mint text (matches welcome.png)
    localparam WELCOME_BG       = 12'h012; // dark navy
    localparam BONE             = 12'hEEC; // skull (go_skull_youdied_2c_butcher)
    localparam BLOOD            = 12'hD11; // "YOU DIED" text

    reg [1:0] state = IDLE;


    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:      state <= keyPressed ? PLAY      : IDLE;
                PLAY:      state <= crash      ? GAME_OVER : PLAY;
                GAME_OVER: state <= keyPressed ? IDLE      : GAME_OVER;
                default:   state <= IDLE;
            endcase
        end
    end


    // Idle screen - game welcome screen, 100x75, one bit per grid cell
    reg [GRID_X-1:0] welcome [0:GRID_Y-1];
    initial $readmemb("welcome.mem", welcome);


    // Game over screen - 200x150 hires bitmap (go_skull_youdied_2c_butcher,
    // "low" tier from hires_screens/: pure LUT-ROM, no BRAM)
    localparam SW = 200, SH = 150;
    reg [SW-1:0] skull [0:SH-1];
    initial $readmemb("skull.mem", skull);

    // ROM reads registered: keeps the big bitmap muxes out of the
    // pixel_color timing path. 1 clk of latency = half a pixel, invisible.
    reg on_welcome_q, on_skull_q, blood_zone_q;
    always @(posedge clk) begin
        on_welcome_q <= welcome[y][GRID_X-1-x];
        on_skull_q   <= skull[sy][SW-1-sx];
        blood_zone_q <= (sy >= 9'd100);   // below the skull: the "YOU DIED" text
    end


    // block color assignment - priority: head > food > snake body > background
    always @(*) begin
        block_color = BLACK; // default - no branch may leave it unassigned (latch!)
        case (state)
            IDLE: begin
                block_color = on_welcome_q ? WELCOME_FG : WELCOME_BG;
            end
            PLAY: begin
                if      (is_head)  block_color = SNAKE_HEAD_COLOR;
                else if (is_food)  block_color = FOOD_COLOR;
                else if (on_snake) block_color = SNAKE_COLOR;
                else               block_color = GREEN;
            end
            GAME_OVER: begin
                block_color = on_skull_q ? (blood_zone_q ? BLOOD : BONE) : BLACK;
            end
            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY);
    assign in_idle     = (state == IDLE);

endmodule
