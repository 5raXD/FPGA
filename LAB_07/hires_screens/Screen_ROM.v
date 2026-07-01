`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Screen_ROM  -  1-bit BRAM image ROM for a full-screen bitmap.
//
// Holds a W x H monochrome image (one bit per pixel), initialised from a
// row-packed .mem file (H lines of W binary digits, produced by the
// fpga-pixel-art toolkit's write_mono_mem / to_mem). Same bit convention as
// the original welcome.mem / skull.mem:  pixel = rom[y][W-1-x].
//
// The row read is registered so Vivado infers BRAM instead of a huge LUT-ROM.
// y is constant across a scan-line, so the 1-cycle latency only affects the
// very first pixel of each line (hidden in the porch) - no visible shift.
//
// Coordinate scaling lives in the caller:  200x150 -> x=XCoord>>2, y=YCoord>>2
//                                           400x300 -> x=XCoord>>1, y=YCoord>>1
//                                           800x600 -> x=XCoord,    y=YCoord
//////////////////////////////////////////////////////////////////////////////////

module Screen_ROM #(
    parameter W  = 400,               // image width  in pixels
    parameter H  = 300,               // image height in pixels
    parameter XW = 9,                 // bits to index x (>= clog2(W))
    parameter YW = 9,                 // bits to index y (>= clog2(H))
    parameter MEMFILE = "screen.mem"  // row-packed, H lines of W bits ($readmemb)
)(
    input  wire          clk,
    input  wire [XW-1:0] x,           // 0 .. W-1
    input  wire [YW-1:0] y,           // 0 .. H-1
    output wire          pixel        // 1 = foreground
);
    (* rom_style = "block" *) reg [W-1:0] rom [0:H-1];
    initial $readmemb(MEMFILE, rom);

    reg [W-1:0] row;
    always @(posedge clk) row <= rom[y];   // registered read -> BRAM

    assign pixel = row[W-1-x];             // matches rom[y][W-1-x]
endmodule
