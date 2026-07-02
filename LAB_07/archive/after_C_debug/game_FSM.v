`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:  Saleh Khalil, Mahmood Stitia
// Module:    game_FSM   (after_C_debug)
//
// Top-level game state machine. Lifted out of GridMapper so the same game_state
// can both pick the screen (welcome / play / game-over) AND hold the Snake in
// reset whenever we are not playing - that is what makes "press reset -> welcome"
// and "Enter -> fresh game" work. See changes.html.
//
//   IDLE  --enter-->  PLAY  --crash-->  GAME_OVER  --enter-->  IDLE
//   (any state) --reset--> IDLE
//////////////////////////////////////////////////////////////////////////////////

module game_FSM(
    input  wire        clk,
    input  wire        reset,   // synchronous, from the debounced btnC
    input  wire        enter,   // 1-cycle pulse: Enter key was pressed
    input  wire        crash,   // from Snake
    output reg  [1:0]  state
    );

    localparam IDLE = 2'b00, PLAY = 2'b01, GAME_OVER = 2'b10;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:      if (enter) state <= PLAY;
                PLAY:      if (crash) state <= GAME_OVER;
                GAME_OVER: if (enter) state <= IDLE;
                default:   state <= IDLE;
            endcase
        end
    end

endmodule
