# Welcome screen variations — 200×150, 1-bit

Open **`picks.html`** in a browser to compare all of them side by side.
Every `.mem` here is the same format as the current game-over screen
(`skull.mem`): 150 lines × 200 binary digits, read as `rom[sy][199-sx]` with
`sx = XCoord>>2`, `sy = YCoord>>2`. Pure LUT-ROM, no BRAM.

## The variants

| file | style | credits? | colors (localparam) |
|---|---|---|---|
| `wc_horror_butcher` | dripping Butcherman title — **matches the game-over art** | no | FG `12'hD11` blood / FG2 `12'hEEC` bone below `sy=96`, BG `12'h000` |
| `wc_horror_butcher_credits` | same + "BROUGHT TO YOU BY MAHMOOD & SALEH" | yes | same |
| `wc_gothic_pirata` | blackletter, distressed edges | no | FG `12'hEEC`, BG `12'h000` |
| `wc_retro_arcade` | arcade cabinet: frame, blocky 5×7 SNAKE, INSERT COIN | no | FG `12'h0F0`, BG `12'h000` |
| `wc_retro_arcade_credits` | same + "BY MAHMOOD AND SALEH" | yes | same |
| `wc_retro_coil_credits` | Nokia Snake II traced art + credits strip | yes | FG `12'h6E2`, BG `12'h021` (gameboy) |
| `wc_retro_coil_solo_credits` | same art with the noisy second snake removed, coil recentered | yes | FG `12'h6E2`, BG `12'h021` (gameboy) |
| `wc_retro_coil_duo_credits` | both snakes, second snake de-noised (sparse scales, more zeros inside) | yes | FG `12'h6E2`, BG `12'h021` (gameboy) |
| `wc_retro_coil_v2` | **best quality**: tile-perfect re-trace from the full-res wallpaper (96×64 native ×2) | no | FG `12'h6E2`, BG `12'h021` (gameboy) |
| `wc_retro_coil_v2_credits` | same tile-perfect re-trace + credits strip | yes | FG `12'h6E2`, BG `12'h021` (gameboy) |
| `wc_modern_minimal` | letterspaced wordmark, hairline rule, lowercase prompt | no | FG `12'h3D9`, BG `12'h012` (current colors) |
| `wc_modern_type` | big bold "snake." + tiny "mahmood x saleh" | yes | FG `12'hEEE`, BG `12'h111` |

## How to use one (2 small edits, no Vivado re-import)

1. Copy your pick over the registered file:
   ```bash
   cp welcome_screens/<pick>.mem welcome.mem
   ```
2. In `grid_mapper.v`, make the welcome ROM hires exactly like the skull ROM:
   ```verilog
   // was: reg [GRID_X-1:0] welcome [0:GRID_Y-1];
   reg [SW-1:0] welcome [0:SH-1];              // SW=200, SH=150 already exist
   initial $readmemb("welcome.mem", welcome);

   // in the registered-read block, was: welcome[y][GRID_X-1-x]
   on_welcome_q <= welcome[sy][SW-1-sx];
   ```
3. Set `WELCOME_FG` / `WELCOME_BG` to the table row above. For the two-tone
   butcher variants add a split rule, same pattern as the game-over screen:
   ```verilog
   IDLE: block_color = on_welcome_q
                     ? (welcome_zone_q ? 12'hEEC : 12'hD11)  // bone below, blood title
                     : 12'h000;
   // alongside blood_zone_q:  welcome_zone_q <= (sy >= 9'd96);
   ```

Regenerate / tweak: `python3 <scratchpad>/gen_welcome.py` (the script lives in
the session scratchpad; it imports `~/.claude/skills/fpga-pixel-art`). Fastest
tweaks: text, sizes, `top=` rows, split rows, and colors are all literals.

## On the credits line

Recommended: **yes, keep it** — it's a classic arcade convention (like
"© 1980 NAMCO" on attract screens), it looks intentional when it's small and
dim, and your names are visible in the demo photo that goes in the report.
Guidelines used here: bottom strip, ~9 px font (reads fine at 4× on the
monitor), never brighter than the PRESS ANY KEY prompt. On two-tone variants
the credits sit in the dimmer color zone automatically.
