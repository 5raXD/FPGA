# LAB_07_2P - two-player snake, Icarus Verilog build
# make        - compile
# make run    - run the system testbench (add +vcd inside for waves)
# make wave   - run with VCD dump
# make clean

SRC = snake_game_2p.v \
      snake.v \
      Direction_Ctrl.v \
      Food_Manager.v \
      Font_ROM.v \
      Hud.v \
      Sound_FX.v \
      grid_mapper.v \
      Pixel_Painter.v \
      VGA_Interface.v \
      Ps2_Interface.v \
      Debouncer.v \
      Seg_7_Display.v \
      game_tick.v

TB  = tb_snake_2p.v

snake_2p.out: $(SRC) $(TB)
	iverilog -g2012 -o $@ $(TB) $(SRC)

.PHONY: run wave clean
run: snake_2p.out
	vvp snake_2p.out

wave: snake_2p.out
	vvp snake_2p.out +vcd

clean:
	rm -f *.out *.vcd
