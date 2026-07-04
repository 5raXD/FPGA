`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     07/03/2026
// Design Name:     FPGA Lab 7 - Snake (2 players)
// Module Name:     GridMapper
// Project Name:    lab7_2p
// Target Devices:  Xilinx BASYS3 Board, FPGA model XC7A35T-1CPG236C
// Tool versions:   Vivado 2023.2 / Icarus Verilog (simulation)
// Description:     Screen FSM + color ROM, 2-player edition.
//                  IDLE      - welcome bitmap, any key -> PLAY
//                  PLAY      - the field: two snakes, food, flashing bonus
//                  GAME_OVER - skull bitmap (winner text drawn by Hud),
//                              any key -> IDLE
//
//                  Color priority in PLAY:
//                  head1 > head2 > bonus > food > body1 > body2 > background
//                  (heads can never overlap on screen: a head-to-head move
//                  crashes both snakes before either head is drawn there)
//////////////////////////////////////////////////////////////////////////////////

module GridMapper #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire start,                    // menu confirm: leaves the welcome screen
    input  wire key_any,                  // any key/button: leaves the game-over screen
    input  wire [$clog2(GRID_X)-1:0] x,   // grid cell (XCoord>>3) - checkerboard
    input  wire [$clog2(GRID_Y)-1:0] y,   // grid cell (YCoord>>3) - checkerboard
    input  wire [8:0] sx,                 // hires pixel (XCoord>>2) - screens
    input  wire [8:0] sy,                 // hires pixel (YCoord>>2) - screens
    input  wire crash,                    // either player crashed
    input  wire is_food,
    input  wire is_bonus,
    input  wire on_snake1,
    input  wire is_head1,
    input  wire on_snake2,
    input  wire is_head2,
    // Outputs
    output wire grid_enable,
    output wire in_idle,                  // hold the snakes in reset on the welcome screen
    output wire in_over,                  // freeze the survivor / show winner text
    output reg  [11:0] block_color
    );

    // FSM states
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam BLACK        = 12'h000;
    localparam GREEN_EVEN   = 12'h0C0;    // dark green  - checkerboard
    localparam GREEN_ODD    = 12'h0F0;    // light green - checkerboard
    localparam FOOD_COLOR   = 12'hF11;
    localparam BONUS_A      = 12'hF0F;    // bonus food flashes magenta/white
    localparam BONUS_B      = 12'hFFF;
    localparam P1_BODY      = 12'h333;    // dark gray
    localparam P1_HEAD      = 12'hFD0;    // warm yellow
    localparam P2_BODY      = 12'h139;    // deep blue
    localparam P2_HEAD      = 12'h0EF;    // cyan
    localparam WELCOME_FG   = 12'h6E2;    // gameboy green (wc_retro_coil_v2)
    localparam WELCOME_BG   = 12'h021;    // dark gameboy background
    localparam BONE         = 12'hEEC;    // skull (go_skull_youdied_2c_butcher)
    localparam BLOOD        = 12'hD11;    // "YOU DIED" text

    reg [1:0] state = IDLE;

    // Chess-board background: a cell is "odd" when x+y is odd. The LSB of
    // x+y is the sum output of a full adder with carry-in 0 (= x[0]^y[0]).
    wire odd_block;

    FA fa(
        .a(x[0]),
        .b(y[0]),
        .ci(1'b0),
        .sum(odd_block),
        .co()                             // carry unused - only the parity matters
    );

    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:      state <= start ? PLAY      : IDLE;
                PLAY:      state <= crash ? GAME_OVER : PLAY;
                GAME_OVER: state <= key_any ? IDLE    : GAME_OVER;
                default:   state <= IDLE;
            endcase
        end
    end

    // bonus food flash - free running counter, bit 23 toggles at ~6 Hz
    reg [23:0] flash_cnt = 0;
    always @(posedge clk) flash_cnt <= flash_cnt + 1;

    // 200x150 hires bitmaps ("low" tier from hires_screens/: pure LUT-ROM,
    // no BRAM). Both screens are sampled at sx = XCoord>>2, sy = YCoord>>2.
    localparam SW = 200, SH = 150;

    // Idle screen - welcome (wc_retro_coil_v2_credits)
    reg [SW-1:0] welcome [0:SH-1];
    initial $readmemb("welcome.mem", welcome);

    // Game over screen - go_skull_youdied_2c_butcher
    reg [SW-1:0] skull [0:SH-1];
    initial $readmemb("skull.mem", skull);

    // ROM reads registered: keeps the big bitmap muxes out of the
    // pixel_color timing path. 1 clk of latency = half a pixel, invisible.
    reg on_welcome_q, on_skull_q, blood_zone_q;
    always @(posedge clk) begin
        on_welcome_q <= welcome[sy][SW-1-sx];
        on_skull_q   <= skull[sy][SW-1-sx];
        blood_zone_q <= (sy >= 9'd100);   // below the skull: the "YOU DIED" text
    end

    // block color assignment
    always @(*) begin
        block_color = BLACK; // default - no branch may leave it unassigned (latch!)
        case (state)
            IDLE: begin
                block_color = on_welcome_q ? WELCOME_FG : WELCOME_BG;
            end
            PLAY: begin
                if      (is_head1)  block_color = P1_HEAD;
                else if (is_head2)  block_color = P2_HEAD;
                else if (is_bonus)  block_color = flash_cnt[23] ? BONUS_A : BONUS_B;
                else if (is_food)   block_color = FOOD_COLOR;
                else if (on_snake1) block_color = P1_BODY;
                else if (on_snake2) block_color = P2_BODY;
                else                block_color = odd_block ? GREEN_ODD : GREEN_EVEN;
            end
            GAME_OVER: begin
                block_color = on_skull_q ? (blood_zone_q ? BLOOD : BONE) : BLACK;
            end
            default: block_color = BLACK;
        endcase
    end

    assign grid_enable = (state == PLAY);
    assign in_idle     = (state == IDLE);
    assign in_over     = (state == GAME_OVER);

endmodule
