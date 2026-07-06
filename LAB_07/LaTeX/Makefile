# Build report.pdf from report.tex without leaving any LaTeX
# byproducts (aux/log/out/toc) in this directory.
# Run: `make` (or `make pdf`).

PDFLATEX ?= pdflatex
NAME     := report
BUILD    := build

.PHONY: all pdf clean distclean

all: pdf

pdf: $(NAME).pdf

$(NAME).pdf: $(NAME).tex
	@mkdir -p $(BUILD)
	@$(PDFLATEX) -interaction=nonstopmode -halt-on-error -output-directory=$(BUILD) $(NAME).tex
	@$(PDFLATEX) -interaction=nonstopmode -halt-on-error -output-directory=$(BUILD) $(NAME).tex
	@cp $(BUILD)/$(NAME).pdf .
	@rm -rf $(BUILD)

clean:
	@rm -rf $(BUILD)

distclean: clean
	@rm -f $(NAME).pdf
