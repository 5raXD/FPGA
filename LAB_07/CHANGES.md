# LAB_07 — Changes

# 2026-07-04 — Merge of Saleh's branch ideas (checkerboard + his structure)

Goal: make the main code follow Saleh's methodology and structure
(`saleh` branch / `fpga-saleh/LAB_07`) as closely as possible, keeping out only
the things that made his build misbehave on the board. His branch was **not**
modified.

## Adopted from Saleh's branch (1P **and** 2P)

1. **Chess-board playfield** — his idea, taken as-is: `FA.v` (the lab-1 full
   adder) with `a = x[0]`, `b = y[0]`, `ci = 0`; the `sum` output is the parity
   of `x + y` (`odd_block`), and a mux picks the cell color:
   `odd_block ? GREEN_ODD (12'h0F0, light) : GREEN_EVEN (12'h0C0, dark)`.
   Roundabout way to get one XOR, but it costs a single LUT and reuses lab-1 IP.
2. **His GridMapper interface** — grid-cell inputs `x`, `y` plus hires screen
   coordinates `img_x`, `img_y` with parametric widths
   (`[$clog2(2*GRID_X)-1:0]`), computed in `Pixel_Painter` as
   `assign img_x = XCoord >> 2;` (replaces the old `sx/sy = XCoord[10:2]`
   slices — same value, his naming and style).
3. **His bitmap declaration style** — `reg [2*GRID_X-1:0] welcome
   [0:2*GRID_Y-1];` (the 200×150 screens expressed as 2× the grid, like his).
4. **His color table** — names and values: `WELCOME_BRIGHT/WELCOME_DARK`,
   `SKULL_COLOR = 12'hEEC`, `DIED_COLOR = 12'hE11` (the game-over red is now
   his E11 instead of the previous D11), `WHITE/BLACK`, `GREEN_EVEN/GREEN_ODD`.
5. **His screen files and welcome art** (1P): `welcome45_raw_200x150.mem`
   (SNAKE graffiti + coiled snake + "By Saleh & Mahmood") and
   `skull_you_died_200x150.mem` (same butcher-skull content as before, his
   filename). `project_7_demo.xpr` re-pointed to the new names; the old
   `welcome.mem`/`skull.mem` were removed (still in git history). His `img/`
   tooling (png2mem converters + PNG previews) copied alongside.
6. **`tick` input restored on `Pixel_Painter`** (his interface keeps it
   reserved for future animations), driven from the top like in his tree.
7. `FA.v` added to the Makefiles and both Vivado projects.

The 2P build got the same conventions (checkerboard, `img_x/img_y`, color
names) but keeps its own screens (`welcome.mem` = TAU art + mode menu,
`skull.mem`) since those don't exist on his branch.

## Deliberately NOT taken (these are what broke his board)

1. **FSM chained-`<=` ternary** (`state <= key ? PLAY : state <= IDLE;`) —
   parses as *less-than-or-equal*, so IDLE self-starts and GAME_OVER/PLAY
   flicker at 50 MHz (details in §3.1 below). A warning comment now sits on
   the FSM so it doesn't come back.
2. **One-hot color `case({on_snake,is_food,is_head})`** — the head is also
   `on_snake` (`3'b101`), which matches nothing and paints the head as
   background. Kept the priority chain head > food > body > background, and
   kept `SNAKE_HEAD_COLOR = 12'hFD0` (his `222` next to body `333` was a
   placeholder — his own `// give me unique color!!!` comment asks for this).
3. **Unwired painter inputs in his top** — `crash/is_food/on_snake/is_head`
   float in his `snake_game.v`, so nothing is ever drawn and the FSM never
   sees a crash. Kept the full wiring.
4. **Raw `keyPressed` into the FSM** — kept the 2-FF synchronizer + edge
   detector (his raw level races GAME_OVER→IDLE→PLAY on one keypress).
5. **His unpipelined `snake.v`** — that is the exact design that failed timing
   at WNS −0.792 ns / TNS −487.8 ns (§1 below). Kept the pipelined one; the
   module interface is identical anyway.

## Verified

* `xvlog` + `xelab` clean for both tops (Vivado 2023.2).
* 2P regression `tb_snake_2p`: **38/38 PASS** after the restructure.
* Both bitstreams rebuilt after the full restructure (new welcome art
  included); post-route, all constraints met:
  1P WNS **+2.017 ns** / WHS +0.112, 2P WNS **+0.550 ns** / WHS +0.083.

---

# 2026-07-02 — Timing fix + integration fixes + new game-over screen

Date: 2026-07-02. Baseline: post-route WNS **−0.792 ns**, TNS **−487.8 ns**, 896
failing endpoints (Vivado project `project_7_demo`, part `xc7a35tlcpg236-2L`).

The architecture was **not** changed: same module split, same 100×75 grid with
8×8-px cells, same body-array snake (`MAX_LEN=64`), same 8 Hz tick, same colors
for background/food/body, same welcome screen.

---

## 1. Why timing failed

The worst path (and all 896 failing endpoints) was:

```
navigation_system/dir_reg ──► next-head adder ──► 64-segment self-collision
comparators (each with a 16-bit "k < length" compare) ──► OR-tree ──► the
clock-enable (CE) of all 64×(7+7) = 896 body_x/body_y registers
```

10 logic levels, 72 % of the delay in routing (the OR-tree output fans out to
896 CE pins spread over the chip). All of that had to settle in one 10 ns
cycle even though the result is only *used* once every 12.5 million cycles
(the 8 Hz `tick`).

A second problem: the empty `IDLE` branch in `GridMapper`'s combinational
`always @(*)` made Vivado infer **12 latches** for `block_color`
(`block_color_reg[*]/G` in the timing report). Latches are both a functional
hazard and a timing hazard.

## 2. Timing fixes (RTL)

### `snake.v` — pipeline the tick-rate logic
The game state is stable for millions of cycles between ticks, so the move
decision is now precomputed in registers instead of one giant cone of logic:

* **Stage 1:** `next_x_r/next_y_r` ⇐ next head position (from `dir` + head).
* **Stage 2:** `hit_self_r`, `hit_wall_r`, `eat_r` ⇐ checks against stage 1,
  and `next_x_rr/next_y_rr` ⇐ stage 1 delayed once more, so the flags and the
  cell used for the actual move always describe the **same** candidate cell
  (no inconsistency window, no gameplay change — worst case a direction change
  lands one 10 ns cycle later, at 8 Hz that is imperceptible).

At `tick` the update logic now reads only flip-flop outputs through 1–2 LUTs.
The 64-way comparator chains each end in a single register instead of fanning
out to 896 CE pins.

* Registered the display **read ports** (`on_snake`, `is_head`, `is_food`).
  The queried cell `(x,y)` changes only every 16 clk (8 px × 2 clk/px), so one
  cycle of latency shifts the drawn edge by half a pixel — invisible — and
  removes the 64-way comparator from the VGA `pixel_color` path.
* `length` shrunk from 16 bits to 7 (`$clog2(64)+1`); the 128 `k < length`
  comparators (collision loop + read-port loop) got 9 bits narrower each.
  `score` is zero-extended to 16 bits for the 7-segment display.

### `grid_mapper.v` — kill the latches, register the bitmap ROMs
* `block_color` gets a default assignment before the `case`, and the `IDLE`
  branch now actually draws the welcome screen → **no more latches**.
* Bitmap reads (`welcome`, `skull`) are registered (`on_welcome_q`,
  `on_skull_q`), keeping the big LUT-ROM row/column muxes out of the pixel
  color path. Again a half-pixel shift, invisible.


## 3. Functional bugs fixed (they blocked the intended game flow)

1. **`GridMapper` FSM `<=` parsing bug** — lines like
   `state <= keyPressed ? PLAY : state <= IDLE;` parse the *inner* `<=` as
   **less-than-or-equal**, so e.g. GAME_OVER with no key evaluated
   `state <= (state<=GAME_OVER)` = `state <= 1` = PLAY. The FSM could never
   hold a state. Rewritten as plain ternaries.
2. **Reset state** — was forced to `GAME_OVER` (the old `// fix me` debug
   hack). Now `IDLE` (welcome screen), as originally intended.
3. **Top-level wiring** — `Pixel_Painter`'s `crash / is_food / on_snake /
   is_head` inputs were left unconnected in `snake_game.v` (they floated), so
   the snake was never actually drawn. `Snake.is_food` and `.keyPressed` were
   also unconnected. All wired now.
4. **Snake head was invisible** — the head cell has `on_snake=1 && is_head=1`
   (`3'b101`), which matched no case item and fell through to the *background*
   color. Replaced the one-hot `case` with a priority if/else
   (head > food > body > background) and gave the head its own color
   (`SNAKE_HEAD_COLOR = 12'hFD0`, warm yellow — change the localparam if you
   want another).
5. **New-game restart** — after GAME_OVER→IDLE there was nothing to
   re-initialize the snake (only the reset button did). Now `GridMapper`
   exports `in_idle`, and the top holds `Snake` + `Navigation_System` in reset
   while the welcome screen is shown (`game_reset = reset | game_idle`).
   Flow: **welcome → any key → play → crash → game-over (score stays on the
   7-seg) → any key → welcome → any key → new game.**
6. **PS/2 → 100 MHz clock-domain crossing** — `keyPressed` comes from the
   PS2Clk domain and stays high for ~60 µs (thousands of clk cycles). It is
   now passed through a 2-FF synchronizer + edge detector in `snake_game.v`,
   producing a clean single-cycle pulse. Without this, one keypress would race
   the FSM through GAME_OVER→IDLE→PLAY in two cycles, and the async input
   could go metastable.


## 4. Files touched

| file | change |
|---|---|
| `snake.v` | tick-logic pipeline, registered read ports, 7-bit `length` |
| `grid_mapper.v` | FSM fix, latch fix, welcome/IDLE colors, 200×150 game-over ROM (registered), head color, `in_idle` output |
| `Pixel_Painter.v` | pass `sx/sy` (>>2) to GridMapper, pass-through of game signals, `game_idle` output, dropped unused `tick`/`start_game` ports |
| `snake_game.v` | full wiring, PS/2 synchronizer + pulse, `game_reset = reset \| game_idle` |
| `task3.xdc` | `ps2_clk` clock + async clock groups |

## 7. How it was verified

* `xvlog` + `xelab snake_game` (Vivado 2023.2): clean compile & elaboration.
* Full non-project batch `synth_design → opt → place → phys_opt → route →
  report_timing_summary` on `xc7a35tlcpg236-2L`. **Result:**

  |            | before      | after       |
  |------------|-------------|-------------|
  | WNS        | **−0.792 ns** | **+2.225 ns** |
  | TNS        | −487.8 ns   | 0.0 ns      |
  | failing endpoints | 896  | 0           |
  | hold (WHS) | met         | met (+0.169 ns) |
  | latches    | 12          | **0**       |
  | Slice LUTs | —           | 1239 (5.96 %) |
  | Registers  | —           | 1112 (2.67 %) |
  | Block RAM  | 0           | 0 (200×150 screen fits in LUT-ROM) |

