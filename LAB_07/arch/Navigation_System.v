`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Navigation_System(
    input  wire clk,
    input  wire reset,
    input  wire tick,
    input  wire [7:0] scancode,
    input  wire keyPressed,
    output reg  [1:0] dir
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    // direction the snake actually moved on the last tick - reversal must be
    // blocked against this, not against dir, otherwise two quick presses
    // inside one tick (e.g. RIGHT: press UP then LEFT) reverse into the body
    reg [1:0] moved_dir;

    always @(posedge clk) begin
        if (reset) begin
            dir <= RIGHT;
            moved_dir <= RIGHT;
        end else begin
            if (tick)
                moved_dir <= dir;
            if (keyPressed) begin
                case (scancode)
                    8'h6B: if (moved_dir != RIGHT) dir <= LEFT;   // numpad 4 = Left
                    8'h74: if (moved_dir != LEFT)  dir <= RIGHT;  // numpad 6 = Right
                    8'h75: if (moved_dir != DOWN)  dir <= UP;     // numpad 8 = Up
                    8'h73: if (moved_dir != UP)    dir <= DOWN;   // numpad 5 = Down
                endcase
            end
        end

    end
endmodule
