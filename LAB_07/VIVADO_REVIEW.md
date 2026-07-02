# Vivado run review — snake_game on xc7a35tlcpg236-2L

Reviewed: 2026-07-02, project `project_7_demo` (synth 13:50, impl + bitstream
13:55 — the run made *after* the timing/integration rework in `CHANGES.md`).
Sources of truth: `project_7_demo.runs/{synth_1,impl_1}/runme.log` and the
routed `*.rpt` reports.

---

## 1. Bottom line

| Check | Result | Verdict |
|---|---|---|
| Synthesis | Complete, **3 warnings** (was 13 + 1 critical) | ✅ |
| Implementation | Complete, `write_bitstream` OK, **0 warnings** | ✅ |
| Setup timing (WNS) | **+2.225 ns** (was **−0.792 ns**) | ✅ met |
| Total negative slack (TNS) | **0.0 ns**, 0 of 2191 endpoints failing (was −487.8 ns / 896) | ✅ met |
| Hold timing (WHS) | +0.169 ns, 0 failing | ✅ met |
| Pulse width (WPWS) | +4.500 ns | ✅ met |
| Routing | 2302/2302 nets fully routed, 0 errors | ✅ |
| DRC (routed) | **0 violations** | ✅ |
| Methodology | 30 warnings (see §4 — none blocking) | ⚠️ cosmetic |
| Latches | **0** (was 12 — `block_color` latch bug fixed) | ✅ |

The design now closes timing with a **3.0 ns improvement** in worst slack and
~22 % margin on the 10 ns clock. The bitstream at
`project_7_demo.runs/impl_1/snake_game.bit` is safe to program.

## 2. Resource utilization (placed)

| Resource | Used | Available | % |
|---|---|---|---|
| Slice LUTs | 1239 | 20800 | 5.96 |
| Slice Registers | 1112 | 41600 | 2.67 |
| Slices | 389 | 8150 | 4.77 |
| F7 / F8 muxes | 23 / 5 | — | ~0.1 |
| Block RAM | **0** | 50 | 0.00 |
| LUT as Memory | 0 | 9600 | 0.00 |
| Bonded IOB | 30 | 106 | 28.3 |
| BUFG | 2 | 32 | 6.25 |

Takeaways:
* The 200×150 game-over bitmap + 100×75 welcome bitmap live entirely in
  logic-LUT ROM — **zero BRAM used**, as planned for the "low" hires tier.
  There is enormous headroom (94 % LUTs, all 50 BRAMs free) if you ever want
  the 400×300 mono or 16-color screens from `hires_screens/`.
* The register count (~1112) is dominated by the snake body array
  (64 × 14 = 896) — inherent to the shift-register body design and fine.

## 3. Power (routed estimate)

Total on-chip **0.092 W** (0.024 W dynamic + 0.068 W static), junction 25.5 °C.
Nothing to do here — this is a near-idle Artix-7.

## 4. Warnings — what they are and whether they matter

### Synthesis (3)
1. **`[Synth 8-7129] Port sx[8] in module GridMapper ... no load` (×2).**
   Benign. `sx` is 9 bits so it can represent the full 0–259 scan range, but
   the 200-wide bitmap index only needs bits [7:0] within the visible area;
   synthesis proves bit 8 is never needed and prunes it. Off-screen values
   land in the blanking region where VGA outputs black anyway. Could be
   silenced by clamping, not worth the logic.
2. **`[Synth 8-7080] Parallel synthesis criteria is not met`.** Informational:
   the design is too small to benefit from multithreaded synthesis. Ignore.

### Implementation (0)
The previous run's **1 critical warning is gone** and the impl log is
warning-free.

### Methodology report (30 — none affect function or the met timing)
* **28 × TIMING-18 "Missing input or output delay"** — no `set_input_delay` /
  `set_output_delay` on the I/O ports (PS2Data, VGA pins, 7-seg pins, rst).
  Standard for a lab project: VGA/7-seg are human-speed outputs and the PS/2
  input is handled as asynchronous. To silence properly, add false-path or
  nominal I/O delay constraints (see §5.1).
* **1 × TIMING-10 "Missing ASYNC_REG on synchronizer"** — Vivado found the
  `kp_sync` 2-FF synchronizer but the registers lack the `ASYNC_REG` property
  (it keeps the two FFs packed in the same slice for best MTBF). One-line fix,
  see §5.1 — worth doing.
* **1 × TIMING-9 "Unknown CDC logic"** — the `scancode[7:0]` bus crosses
  PS2Clk→clk covered by the `set_clock_groups` but without its own per-bit
  synchronizer. This is safe *by design timing* (scancode settles ~60 µs
  before the synchronized keyPressed pulse samples it), but the tool can't
  prove that. Acceptable as-is; §5.2 shows the "textbook" alternative.

## 5. What's left to improve

### 5.1 Cheap wins (recommended before submission)
* **Add `ASYNC_REG` to the synchronizer** (fixes TIMING-10) in `snake_game.v`:
  ```verilog
  (* ASYNC_REG = "TRUE" *) reg [2:0] kp_sync = 3'b000;
  ```
* **Constrain the I/O ports** (fixes the 28 TIMING-18s) in `task3.xdc`, e.g.:
  ```tcl
  set_false_path -from [get_ports {rst PS2Data}]
  set_false_path -to   [get_ports {vgaRed[*] vgaGreen[*] vgaBlue[*] Hsync Vsync a_to_g[*] an[*] dp}]
  ```
  (Honest and accurate here: the monitor and 7-seg don't care about ns-level
  skew, and the async inputs are synchronized internally.)
* **Delete `Renderer.v` from the Vivado sources** — empty `// delete me` stub,
  already auto-disabled, just clutter.

### 5.2 Nice-to-haves (functional polish, not required)
* **Food can spawn on the snake body.** `farmer` output isn't checked against
  occupancy. Easy fix at tick rate: if the newly latched plant cell hits the
  body, re-latch next cycle(s) until it doesn't (LFSR free-runs, so it
  converges fast). The old `food_on_snake` port stub hinted at this plan.
* **Score displays in hex** (length 10 shows "000A" → the display maps A to a
  dash). A double-dabble binary→BCD converter before `Seg_7_Display` would
  show decimal. At tick rate this is cheap.
* **Score counts the head** (starts at 1, shows 1 before any food). Showing
  `length-1` = apples eaten may read more naturally.
* **Win condition:** at `MAX_LEN=64` the snake silently stops growing. Could
  flash a "YOU WIN" screen (plenty of LUT/BRAM headroom for a third bitmap).
* **Speed ramp:** make `Game_Tick`'s terminal count shrink with score for
  increasing difficulty — trivial parameter-to-register change.
* **Sync `scancode` formally** (silences TIMING-9): register scancode into the
  clk domain when the synchronized pulse fires, and let `Navigation_System`
  consume the registered copy one cycle later.
* **Hi-res welcome screen:** the game-over screen is now 200×150; the welcome
  screen is still the blocky 100×75. Same 5-line pattern in `GridMapper`
  (bitmaps ready in `imgs_pixils/pics_hd/low/`, e.g. `wc_snake_pressstart`).

### 5.3 For the lab report
The before/after story is exactly what the submission guide asks for
("explain which problems appeared and how you overcame them"):
* Problem: WNS −0.792 ns / TNS −487.8 ns / 896 failing endpoints on the
  `dir → next-head → 64-way collision compare → 896 body-register CE` path;
  12 inferred latches on `block_color`; unsynchronized PS/2 crossing.
* Solution: pre-compute the move decision in a 2-stage register pipeline
  (results only consumed at the 8 Hz tick), register the grid/bitmap read
  ports (half-pixel latency, invisible), default-assign `block_color`
  (latches → 0), 2-FF synchronizer + pulse for keyPressed, declare `ps2_clk`
  asynchronous. Result: WNS +2.225 ns, all constraints met, DRC clean,
  bitstream generated.
