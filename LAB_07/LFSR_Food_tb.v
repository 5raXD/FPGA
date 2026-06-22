`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module LFSR_TB();

    reg clk;
    wire [6:0] food_x;
    wire [6:0] food_y;

    integer f;


    LFSR_Food #(.GRID_X(100), .GRID_Y(75)) dut(
        .clk(clk),
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
        repeat(2*7500) #5 clk = ~clk; // Almost 1 hit per block
        $finish;
    end

    always @(posedge clk) begin
        $fdisplay(f, "(%d, %d)", food_x, food_y);
    end

    final $fclose(f);


endmodule