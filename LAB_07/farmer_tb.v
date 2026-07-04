`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module farmer_tb();

    reg clk;
    reg keyPressed;
    wire [6:0] food_x;
    wire [6:0] food_y;

    parameter GRID_X = 100;
    parameter GRID_Y = 75;

    integer f;


    farmer #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) dut(
        .clk(clk),
        .keyPressed(keyPressed),
        .food_x(food_x),
        .food_y(food_y)
    );

    always #5 clk = ~clk;

    initial begin

        if($test$plusargs("vcd")) begin
            $dumpfile("LFSR_Food.vcd");
            $dumpvars(0, farmer_tb);
        end
    
        f = $fopen("coords.txt", "w");

        clk = 0;
        keyPressed = 0;
        repeat(2*GRID_X*GRID_Y) #5 clk = ~clk; // Almost 2 hit per block
        $finish;
    end

    always @(posedge clk) begin
        keyPressed = (({$random} % 100) < 1); // high ~1% of clocks
        $fdisplay(f, "(%d, %d)", food_x, food_y);
    end

endmodule