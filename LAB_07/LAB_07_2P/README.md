# LAB_07_2P — Snake with 1P / 2P mode select (Basys3)

Bonus-feature fork of `LAB_07` (which stays untouched as the plain 1-player
submission). The welcome screen (TAU-logo art) shows a **mode menu**:

```
        1 PLAYER          <- UP / numpad 1
        2 PLAYERS         <- DOWN / numpad 2
```
Move the cursor with **UP/DOWN** (keyboard or buttons) or **numpad 1/2**;
start with **LEFT/RIGHT or Enter**. Both modes get the full experience:
score HUD, bonus food, sound, decimal 7-seg.

**Player 1** (gray body / **yellow** head) — PS/2 keyboard, numpad **4/6/8/5**.
**Player 2** (blue body / **cyan** head) — board buttons **btnU/btnD/btnL/btnR**.
2P: shared field, shared food. **First to crash loses.** Head-to-head on the
same cell = both crash = draw. 1P: P2 doesn't exist (not drawn, no collisions,
7-seg right pair blank, no winner text — just the skull on game over).

## What's new vs LAB_07

| Feature | Where |
|---|---|
| **1P / 2P mode menu** on the welcome screen — opaque picker box, selected line bright; mode latched at start (`sel_2p` / `mode_2p`) | `Hud.v`, top |
| **TAU welcome art** — `welcome_screens/img/welcome_raw.mem` (SNAKE + university logo + credits) | `welcome.mem` |
| **Reversal-bug fix** — turns are validated against `dir_committed` (the direction actually moved last tick), so two quick presses in one tick window can no longer 180° the snake into its own neck | `Direction_Ctrl.v` |
| **Two snakes** — cross-collision query ports, head-to-head detection, survivor freeze on game over | `snake.v`, top |
| **Winner screen** — skull art + "P1 WINS" / "P2 WINS" / "DRAW" in 32px pixel letters (empty band Y 544-575 of the skull bitmap), colored per winner; 2P only | `Hud.v`, `grid_mapper.v` |
| **Score HUD on VGA** — "P1 nn" / "P2 nn" pixel text, top band, player-colored (P2 hidden in 1P) | `Hud.v`, `Font_ROM.v` |
| **Bonus food** — spawns every ~12 s, lives ~5 s, flashes magenta/white, **+3 points** (normal food +1; growth +1 either way) | `Food_Manager.v` |
| **Fair food spawning** — no modulo bias (rejection sampling) and never on a snake / the other food / under the HUD (3-cycle free-cell handshake with both snakes) | `Food_Manager.v` |
| **Sound FX** — eat blip (E6), bonus chirp (G6→C7), death tone (B4→E4→A3) as square waves on **Pmod JA1** | `Sound_FX.v` |
| **Decimal scores** — 7-seg shows P1 on the left digit pair, P2 on the right (BCD, capped at 99; the dot separates players) | top + `Seg_7_Display.v` |

## Hardware setup
- VGA monitor + PS/2 keyboard as in LAB_07; **btnC = reset**.
- Speaker: passive piezo buzzer between **JA1** (top-left Pmod pin J1) and any JA **GND** pin. Optional — everything works without it.

## Files
- Top: `snake_game_2p.v` (params: `TICK_MAX`, `BONUS_PERIOD`, `BONUS_LIFE`)
- New: `Direction_Ctrl.v`, `Food_Manager.v`, `Font_ROM.v`, `Hud.v`, `Sound_FX.v`
- Reworked: `snake.v`, `grid_mapper.v`, `Pixel_Painter.v`
- Copied from LAB_07: `VGA_Interface.v`, `Ps2_Interface.v`, `Debouncer.v`, `Seg_7_Display.v`, `game_tick.v`, `welcome.mem`, `skull.mem` (both 200×150)
  - `Debouncer.v` / `Ps2_Interface.v` got power-up initial values (Vivado honors them; keeps X out of the food LFSR in simulation)
- Constraints: `task_2p.xdc` (buttons + JA1 uncommented)
- Test: `tb_snake_2p.v` — 38 self-checking tests incl. the double-turn regression, menu flow and a full 1P scenario; **all pass** (xsim 2023.2)
- Vivado project: `../../project_7_2_players/` (sources referenced in place via `$PPRDIR/../fpga/LAB_07/LAB_07_2P/`)

## Build / simulate
Vivado xsim (no iverilog on this machine):
```bash
mkdir -p /tmp/vlibs && ln -sf /usr/lib/libtinfo.so.6 /tmp/vlibs/libtinfo.so.5
source ~/Downloads/fpgalabtryInstall/Vivado/2023.2/settings64.sh
export LD_LIBRARY_PATH=/tmp/vlibs:$LD_LIBRARY_PATH
mkdir /tmp/run2p && cd /tmp/run2p && cp <this dir>/{welcome,skull}.mem .
xvlog <this dir>/*.v && xelab tb_snake_2p -s sim && xsim sim -R
```
Synthesis: new Vivado RTL project, add all `.v` except `tb_snake_2p.v`, add both
`.mem`, add `task_2p.xdc`, top = `snake_game_2p`, part `xc7a35tcpg236-1`
(or `xc7a35tlcpg236-2L` like the lab project).

## Design notes (for the report)
- Same 2-stage tick pipeline as LAB_07 (stage 1: candidate head; stage 2:
  wall/self/other/eat flags). Cross-snake checks reuse it: each snake's
  stage-1 candidate feeds the other's registered query port, so the 64-way
  comparators stay out of the 10 ns paths.
- Moving into the cell just vacated by the other snake's tail still counts
  as a hit (flags compare against the pre-move body) — standard simplification.
- If both crash on the same tick (incl. head-to-head), it's a draw.
- Winner text sits at Y 544-575 — verified empty in `skull.mem`.
