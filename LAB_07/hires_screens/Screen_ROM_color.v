`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Screen_ROM_color  -  16-colour BRAM image ROM.
//
// Holds a W x H image as 4-bit palette indices (linear address y*W + x,
// $readmemh from <name>.mem) plus a 16-entry palette of 12-bit 0xRGB colours
// ($readmemh from <name>_pal.mem). Both files come from the fpga-pixel-art
// toolkit (write_index_mem / write_palette_mem).
//
// One registered BRAM read; palette lookup is a tiny 16x12 LUT. Feed a linear
// pixel address:  addr = y*W + x  (compute in the caller). The 1-cycle latency
// is hidden the same way as Screen_ROM.
//////////////////////////////////////////////////////////////////////////////////

module Screen_ROM_color #(
    parameter W  = 400,
    parameter H  = 300,
    parameter AW = 17,                     // >= clog2(W*H)  (400*300=120000)
    parameter IMG = "screen.mem",          // W*H lines, 1 hex nibble  ($readmemh)
    parameter PAL = "screen_pal.mem"       // 16 lines, 3 hex digits   ($readmemh)
)(
    input  wire          clk,
    input  wire [AW-1:0] addr,             // y*W + x
    output wire [11:0]   color             // 12-bit RGB for the VGA DAC
);
    (* rom_style = "block" *) reg [3:0] img [0:W*H-1];
    reg [11:0] pal [0:15];
    initial begin
        $readmemh(IMG, img);
        $readmemh(PAL, pal);
    end

    reg [3:0] idx;
    always @(posedge clk) idx <= img[addr];   // registered read -> BRAM
    assign color = pal[idx];
endmodule
