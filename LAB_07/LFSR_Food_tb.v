`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module LFSR_TB();

    reg clk;
    reg keyPressed;
    wire [6:0] food_x;
    wire [6:0] food_y;

    parameter GRID_X = 100;
    parameter GRID_Y = 75;

    integer f;


    LFSR_Food #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) dut(
        .clk(clk),
        .keyPressed(keyPressed),
        .food_x(food_x),
        .food_y(food_y)
    );

    always #5 clk = ~clk;

    initial begin

        if($test$plusargs("vcd")) begin
            $dumpfile("LFSR_Food.vcd");
            $dumpvars(0, LFSR_TB);
        end
    
        f = $fopen("coords.txt", "w");

        clk = 0;
        keyPressed = 0;
        repeat(2*GRID_X*GRID_Y) #5 clk = ~clk; // Almost 2 hit per block
        $finish;
    end

    always @(posedge clk) begin
        keyPressed = ($urandom_range(999) < 1); // high ~0.1% of clocks
        $fdisplay(f, "(%d, %d)", food_x, food_y);
    end

    final $fclose(f);


endmodule