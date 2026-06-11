`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         Tel Aviv University
// Engineer:        Saleh Khalil (213310485), Mahmood Stitia (214032682)
//
// Create Date:     06/07/2026
// Design Name:     FPGA Lab 5 - Keyboard
// Module Name:     Ps2_Interface_tb
// Project Name:    lab5
//
//////////////////////////////////////////////////////////////////////////////////
module Ps2_Interface_tb();

    localparam CLK_HALF = 30_000;   // 30 us half -> 60 us period -> ~16.7 kHz PS/2 clock

    reg PS2Clk, rstn, PS2Data, correct;
    wire [7:0] scancode;
    wire keyPressed;
    wire parity_ok = uut.parity_ok;
    wire [7:0] byte_to_send;


    // Instantiate the UUT (Unit Under Test)
    Ps2_Interface uut(
        .PS2Clk(PS2Clk),
        .rstn(rstn),
        .PS2Data(PS2Data),
        .scancode(scancode),
        .keyPressed(keyPressed)
        );

    initial begin

        if($test$plusargs("vcd")) begin
            $dumpfile("Ps2_Interface_tb.vcd");
            $dumpvars(0, Ps2_Interface_tb);
        end

        correct = 1;
        PS2Clk = 1;  
        PS2Data = 1; 
        rstn = 0;

        #(CLK_HALF);
        rstn = 1;
        #(CLK_HALF);

        // 1- press '5' (0x73)
        byte_to_send = 8'h73;
        send_byte(byte_to_send);
        correct = correct & keyPressed & (scancode == 8'h73);

        // 2- release '5' (F0 73) then press '0' (0x70)
        byte_to_send = 8'hF0;
        send_byte(byte_to_send);
        byte_to_send = 8'h73;
        send_byte(byte_to_send);
        byte_to_send = 8'h70;
        send_byte(byte_to_send);
        correct = correct & keyPressed & (scancode == byte_to_send);

        // 3- hold '0' (auto-repeat 0x70)
        send_byte(byte_to_send);
        correct = correct & ~keyPressed & (scancode == byte_to_send);


        if (correct)
            $display("Test Passed - %m");
        else
            $display("Test Failed - %m");
        $finish;
    end

    // send the pressed key in serial format - 11 bits
    task send_byte(input [7:0] b);
        integer k;
        reg [10:0] frame;
        begin
            frame = {1'b1, ~(^b), b, 1'b0};
            for (k = 0; k < 11; k = k + 1) begin
                PS2Data = frame[k];
                #CLK_HALF;
                PS2Clk = 0;
                #CLK_HALF;
                PS2Clk = 1;
            end
            #(CLK_HALF*4); // idle time gap between presses
        end
    endtask

endmodule
