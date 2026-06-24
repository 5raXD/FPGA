# Build a simulation executable for snake_game and the modules under it.
# Toolchain: Icarus Verilog (SystemVerilog enabled).  Run: `make` then `make run`.

IVERILOG ?= iverilog
VVP      ?= vvp
IVFLAGS  ?= -g2012

TOP := snake_game
OUT := snake_game.out

# snake_game + every module it instantiates (and their submodules)
SRC := \
	snake_game.v \
	Debouncer.v \
	Navigation_System.v \
	Ps2_Interface.v \
	VGA_Interface.v \
	Pixel_Painter.v \
	Game_Tick.v \
	Seg_7_Display.v

##################################################
# add more files here, one per line, e.g.:
#   SRC += my_testbench.v
##################################################


.PHONY: all run clean

all: $(OUT)

$(OUT): $(SRC)
	@$(IVERILOG) $(IVFLAGS) -s $(TOP) -o $(OUT) $(SRC)

run: $(OUT)
	@$(VVP) $(OUT) +vcd

clean:
	@rm -f $(OUT) *.vcd
