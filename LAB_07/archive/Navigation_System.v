`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module Navigation_System(
    input  wire clk,
    input  wire reset,
    input  wire [7:0] scancode,
    input  wire keyPressed,
    // input  wire tick,
    // input  wire [1:0] dir,
    output reg  [1:0] dir
    );

    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;

    reg [1:0] dir_next = RIGHT;

    always @(posedge clk) begin
        if (reset) begin
            dir <= RIGHT;
        end else if (keyPressed) begin
            case (scancode)
                8'h6B: if (dir != RIGHT) dir_next <= LEFT;
                8'h74: if (dir != LEFT) dir_next <= RIGHT;
                8'h75: if (dir != DOWN) dir_next <= UP;
                8'h73: if (dir != UP) dir_next <= DOWN;
            endcase
        end

    end
endmodule