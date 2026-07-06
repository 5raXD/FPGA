`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////


module GridMapper #(parameter GRID_X = 100, GRID_Y = 75)(
    // Inputs
    input  wire clk,
    input  wire reset,
    input  wire keyPressed,
    input  wire [$clog2(GRID_X)-1:0] x,
    input  wire [$clog2(GRID_Y)-1:0] y,
    input  wire [$clog2(2*GRID_X)-1:0] img_x,
    input  wire [$clog2(2*GRID_Y)-1:0] img_y,
    input wire crash,
    input wire is_food,
    input wire on_snake,
    input wire is_head,
    input wire [15:0] score_in,   // real game score from snake.v (via Pixel_Painter): {8'b0, tens_bcd, ones_bcd}
    // Outputs
    output wire grid_enable,
    output reg  [11:0] block_color
    );

    // FSM states
    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam GAME_OVER = 2'b10;

    // Colors
    localparam WHITE = 12'hFFF;
    localparam BLACK = 12'h000;
    localparam GREEN_EVEN = 12'h0C0; // Dark green
    localparam GREEN_ODD = 12'h0F0; // Light green
    localparam FOOD_COLOR = 12'hF11;
    localparam SNAKE_COLOR = 12'h444;
    localparam SNAKE_HEAD_COLOR = 12'h222; // give me unique color!!!
    localparam SKULL_COLOR = 12'hEEC;
    localparam DIED_COLOR = 12'hE11;
    localparam WELCOME_BRIGHT = 12'h6E2;
    localparam WELCOME_DARK = 12'h021;
    localparam SCORE_COLOR = 12'hFD0; // game-over score,yellow (use 12'hF80 for orange)

    reg [1:0] state = IDLE;
    reg [$clog2(GRID_X * GRID_Y)-1:0] score = 0;

    wire odd_block;

    FA fa(
    .a(x[0]),
    .b(y[0]),
    .ci(1'b0),
    .sum(odd_block)
    );


    always @(posedge clk) begin // What screen to display (IDLE, PLAY, GAME_OVER)
        if(reset) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: state <= keyPressed? PLAY : IDLE;
                PLAY: state <= crash? GAME_OVER : PLAY;
                GAME_OVER: state <= keyPressed? PLAY : GAME_OVER;
            endcase

        end
    end


    // Idle screen - game welocome screen
    reg [2*GRID_X-1:0] welcome [0:2*GRID_Y-1];
    initial $readmemb("welcome45_raw_200x150.mem", welcome);
    wire on_welcome = welcome[img_y][2*GRID_X-1-img_x];

    // Game over screen - skull bitmap
    reg [2*GRID_X-1:0] skull [0:2*GRID_Y-1];
    initial $readmemb("skull_you_died_200x150.mem", skull);
    wire on_skull = skull[img_y][2*GRID_X-1-img_x];


    //score overlay on game_over:final 2-digit score, yellow
    reg [15:0] final_score;
    always @(posedge clk) begin
        if (reset)              final_score <= 16'd0;
        else if (state == PLAY) final_score <= score_in;
    end

    //img_y 136..143 (YCoord 544..575).
    //img_x 92..99, ones at img_x 100..107.
    wire in_score_y = (img_y >= 8'd136) && (img_y <= 8'd143);
    wire in_tens    = (img_x >= 8'd92)  && (img_x <= 8'd99);
    wire in_ones    = (img_x >= 8'd100) && (img_x <= 8'd107);
    wire score_region = (state == GAME_OVER) && in_score_y && (in_tens || in_ones);

    wire [3:0] sc_digit = in_tens ? final_score[7:4] : final_score[3:0];
    reg  [63:0] dglyph;
    always @(*) begin
        case (sc_digit)
            4'd0: dglyph = 64'h3C66666666663C00;
            4'd1: dglyph = 64'h1838181818183C00;
            4'd2: dglyph = 64'h3C66060C18307E00;
            4'd3: dglyph = 64'h3C66061C06663C00;
            4'd4: dglyph = 64'h0C1C2C4C7E0C0C00;
            4'd5: dglyph = 64'h7E607C0606663C00;
            4'd6: dglyph = 64'h3C66607C66663C00;
            4'd7: dglyph = 64'h7E060C1830303000;
            4'd8: dglyph = 64'h3C66663C66663C00;
            4'd9: dglyph = 64'h3C66663E06663C00;
            default: dglyph = 64'h0;
        endcase
    end
    wire [2:0] g_row  = img_y[2:0];
    wire [2:0] g_col  = img_x[2:0] - 3'd4;
    wire [7:0] g_bits = dglyph[{3'd7 - g_row, 3'b000} +: 8];
    wire score_pix    = g_bits[3'd7 - g_col];


    // block color assignment - case for display layers (background, snake, food)
    always @(*) begin
        case (state)
            IDLE: begin
                block_color = on_welcome? WELCOME_BRIGHT : WELCOME_DARK;
            end
            PLAY: begin
                casez({on_snake, is_food, is_head})
                    3'b??1: block_color = SNAKE_HEAD_COLOR; // snake head
                    3'b?1?: block_color = FOOD_COLOR; // food
                    3'b1??: block_color = SNAKE_COLOR; // snake body
                    default: block_color = (odd_block)? GREEN_ODD : GREEN_EVEN; // background
                endcase
            end
            GAME_OVER: begin
                block_color = on_skull? ((img_y < 100)? SKULL_COLOR : DIED_COLOR) : BLACK;
            end
            default: block_color = BLACK;
        endcase
        // assignment overrides the case above wherever a digit pixel is lit
        if (score_region && score_pix)
            block_color = SCORE_COLOR;
    end

    assign grid_enable = (state == PLAY);

endmodule