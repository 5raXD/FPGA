`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Navigation_System(
    input  wire clk,
    input  wire reset,
    input  wire [7:0] scancode,
    input  wire keyPressed,
    output reg  [1:0] dir
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;


    always @(posedge clk) begin
        if (reset) begin
            dir <= RIGHT;
        end else if (keyPressed) begin
            case (scancode)
                8'h6B: if (dir != RIGHT) dir <= LEFT;   // numpad 4 = Left
                8'h74: if (dir != LEFT)  dir <= RIGHT;  // numpad 6 = Right
                8'h75: if (dir != DOWN)  dir <= UP;     // numpad 8 = Up
                8'h73: if (dir != UP)    dir <= DOWN;   // numpad 5 = Down
            endcase
        end

    end
endmodule
