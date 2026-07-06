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

    integer i;
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

        for (i=1; i<65; i=i+1) begin
            score = i;
            @(posedge tick);
            repeat(3) @(posedge clk);
        end

        $finish;
    end

    assign tick_speed = dut.tick_speed;
    assign hz =  CLK_FREQ / tick_speed;

endmodule