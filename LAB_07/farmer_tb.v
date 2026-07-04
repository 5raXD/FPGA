`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Simple self-checking testbench for farmer (the LFSR food spawner).
//
// Checks:
//   1. food_x/food_y always land INSIDE the grid (x < 100, y < 75)
//   2. the position keeps moving (a broken/stuck LFSR would freeze)
//   3. the food spreads over most of the board, not one corner
//
// Also writes coords.txt (one "(x, y)" per clock) so coverage.py can still
// draw the screen.png heat-map, and dumps LFSR_Food.vcd when run with +vcd.
//////////////////////////////////////////////////////////////////////////////////

module farmer_tb();

    parameter GRID_X = 100;
    parameter GRID_Y = 75;
    parameter CYCLES = 15000;   // ~2 draws per grid cell

    reg clk = 0;
    reg keyPressed = 0;
    wire [6:0] food_x;
    wire [6:0] food_y;

    farmer #(.GRID_X(GRID_X), .GRID_Y(GRID_Y)) dut(
        .clk(clk),
        .keyPressed(keyPressed),
        .food_x(food_x),
        .food_y(food_y)
    );

    always #5 clk = ~clk;   // the ONE clock driver (old tb had a second one)

    integer i;
    integer f;
    integer errors   = 0;   // out-of-grid samples
    integer changes  = 0;   // how many clocks the position moved
    integer distinct = 0;   // how many different cells were visited
    reg [13:0] prev;
    reg seen [0:GRID_X*GRID_Y-1];

    initial begin
        if($test$plusargs("vcd")) begin
            $dumpfile("LFSR_Food.vcd");
            $dumpvars(0, farmer_tb);
        end

        f = $fopen("coords.txt", "w");
        for(i = 0; i < GRID_X*GRID_Y; i = i + 1) seen[i] = 0;

        @(negedge clk);
        prev = {food_x, food_y};

        for(i = 0; i < CYCLES; i = i + 1) begin
            @(negedge clk);
            // tap the entropy input now and then, like a real keypress would
            keyPressed <= (i % 1000 == 999);

            // check 1: inside the grid
            if(food_x >= GRID_X || food_y >= GRID_Y) begin
                errors = errors + 1;
                if(errors <= 5)
                    $display("FAIL: food outside grid (%0d,%0d) at cycle %0d",
                             food_x, food_y, i);
            end

            // check 2: still moving
            if({food_x, food_y} != prev) changes = changes + 1;
            prev = {food_x, food_y};

            // check 3: board coverage
            if(!seen[food_y*GRID_X + food_x]) begin
                seen[food_y*GRID_X + food_x] = 1;
                distinct = distinct + 1;
            end

            $fdisplay(f, "(%d, %d)", food_x, food_y);
        end

        $fclose(f);

        // -------- summary --------
        if(errors == 0)
            $display("PASS: all %0d samples inside the 100x75 grid", CYCLES);
        else
            $display("FAIL: %0d samples were outside the grid", errors);

        if(changes > CYCLES/2)
            $display("PASS: food keeps moving (%0d/%0d clocks it changed)", changes, CYCLES);
        else
            $display("FAIL: food looks stuck (only moved %0d/%0d clocks)", changes, CYCLES);

        if(distinct > (GRID_X*GRID_Y)/2)
            $display("PASS: good spread - visited %0d of %0d cells", distinct, GRID_X*GRID_Y);
        else
            $display("FAIL: poor spread - visited only %0d of %0d cells", distinct, GRID_X*GRID_Y);

        if(errors == 0 && changes > CYCLES/2 && distinct > (GRID_X*GRID_Y)/2)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
