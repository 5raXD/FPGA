# LAB_07 — Timing fix + integration fixes + new game-over screen

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

### `task3.xdc` — declare the PS/2 clock domain
`PS2Clk` (~15 kHz) is now a declared clock and marked **asynchronous** to the
100 MHz `sys_clk_pin`, so Vivado stops timing keyboard→system crossings
against the 10 ns budget. The crossing is made *safe in RTL* (see §4), not by
the constraint alone.

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

## 4. New game-over screen

`skull.mem` now contains **`hires_screens/go_skull_youdied_2c_butcher`**
(200×150, 1-bit — the "low" tier: pure LUT-ROM, **zero BRAM**). `GridMapper`
indexes it with `sx = XCoord>>2, sy = YCoord>>2` (4× the detail of the old
100×75 skull). The art is one bitplane but two-toned in RTL: rows `sy < 100`
(the skull) draw in bone white `12'hEEC`, rows below (the "YOU DIED" text)
draw in blood red `12'hD11` — matching the PNG preview.

*Why overwrite `skull.mem` instead of adding a new file?* The Vivado project
(`project_7_demo.xpr`) already references `skull.mem`; replacing its content
means **nothing to re-add in Vivado** (and no risk of the open GUI session
overwriting an edited .xpr). The old 100×75 skull is still in git history,
in `archive/skull.mem`, and regenerable with `gameover.py`.

## 5. Efficiency notes (looked at, deliberately left alone)

* `farmer`'s `% 100` / `% 75` of a 7-bit value synthesizes to the same tiny
  conditional-subtract logic you'd write by hand — not a divider. Left as is.
* `Renderer.v` is an empty `// delete me` stub, already auto-disabled in the
  Vivado project and not in the Makefile. Left in place so the project file
  doesn't dangle; delete it from the Vivado sources whenever you like.
* The hires welcome screens in `hires_screens/`… only the game-over screen was
  swapped, as requested. The welcome screen upgrade would be the same 5-line
  pattern in `GridMapper` if you want it later.

## 6. Files touched

| file | change |
|---|---|
| `snake.v` | tick-logic pipeline, registered read ports, 7-bit `length` |
| `grid_mapper.v` | FSM fix, latch fix, welcome/IDLE colors, 200×150 game-over ROM (registered), head color, `in_idle` output |
| `Pixel_Painter.v` | pass `sx/sy` (>>2) to GridMapper, pass-through of game signals, `game_idle` output, dropped unused `tick`/`start_game` ports |
| `snake_game.v` | full wiring, PS/2 synchronizer + pulse, `game_reset = reset \| game_idle` |
| `task3.xdc` | `ps2_clk` clock + async clock groups |
| `skull.mem` | replaced content with 200×150 butcher art |
| `Makefile` | unchanged (same source list) |

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

  *All user specified timing constraints are met.*
* In your open Vivado GUI just hit **Reset Runs → Generate Bitstream**; the
  project reads these sources in place, nothing to re-import.
