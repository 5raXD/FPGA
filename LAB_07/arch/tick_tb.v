`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////



module tick_tb();

    localparam CLK_FREQ = 100_000_000; // 7Hz tick for 100MHz clock

    reg clk;
    reg reset;
    reg [15:0] score;
    wire tick;
    wire [26:0] hz;
    wire [26:0] tick_speed;


    Game_Tick #(.TICK_MAX(14_285_714)) dut ( // 7Hz tick for 100MHz clock
        // Inputs
        .clk(clk),
        .reset(reset),
        .score(score),
        // Outputs
        .tick(tick)
    );

    always #5 clk = ~clk; // 100MHz clock

    initial begin

        if($test$plusargs("vcd")) begin
            $dumpfile("tick_tb.vcd");
            $dumpvars(0, tick_tb);
        end

        clk = 0;
        reset = 1;
        score = 0;
        #10;
        reset = 0;

        #1000; // Wait for some time to observe the tick signal

        // Test case 1: Score < 64
        score = 16'd10;
        #1000; // Wait for some time to observe the tick signal

        // Test case 2: Score >= 64
        score = 16'd50;
        #1000; // Wait for some time to observe the tick signal

        score = 16'd50;
        #1000; // Wait for some time to observe the tick signal

        score = 16'd60;
        #1000; // Wait for some time to observe the tick signal

        score = 16'd64;
        #1000; // Wait for some time to observe the tick signal

        score = 16'd80;
        #1000; // Wait for some time to observe the tick signal

        $finish;
    end

    assign tick_speed = dut.tick_speed;
    assign hz =  CLK_FREQ / tick_speed;

endmodule