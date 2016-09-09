distrib_mk_path := $(lastword $(MAKEFILE_LIST))
%: $(distrib_mk_path)
include $(PDFLATEX_MAKEFILE)

md_to_tex_path := $(dir $(abspath $(distrib_mk_path)))/bin/md2tex.sh
export TEXINPUTS:=.:$(dir $(abspath $(distrib_mk_path))):$(TEXINPUTS)

.PHONY: diff all
diff: $(PDFTARGETS)
	echo $(foreach T,$(PDFTARGETS:.pdf=),$(T).old.pdf $(T).pdf ) | xargs -P 2 -n 2 diffpdf

INDIV_POEMS:=$(patsubst %.md,%.tex,$(wildcard $(POEMS_DIR)/*.md))
SVG_IMAGES:=$(wildcard $(ILLUST_DIR)/*.svg)
JPG_IMAGES:=$(wildcard $(ILLUST_DIR)/*.jpg)
IMAGES:=$(SVG_IMAGES) $(JPG_IMAGES)
EPS_IMAGES:=$(SVG_IMAGES:.svg=.eps) $(JPG_IMAGES:.jpg=.eps)

$(PDFTARGETS): $(INDIV_POEMS) $(IMAGES)

TEX4HTEXTS:=4tc 4ct 4cc css dvi idv lg tmp xref
METAD_EXTS:=top ctn idx ilg ind
POETRY_STYLESHEET:=$(dir $(abspath $(distrib_mk_path)))/poetry_ebook.css

EXTRACLEAN += $(INDIV_POEMS) $(EPS_IMAGES) texput.log
EXTRACLEAN += $(foreach EXT,$(TEX4HTEXTS),$(TARGETS:=.$(EXT)))
EXTRACLEAN += $(foreach EXT,$(METAD_EXTS),$(TARGETS:-.$(EXT)))
EXTRADISTCLEAN += $(TARGETS:=.html) $(TARGETS:=.epub) $(TARGETS:=.azw3)

$(POEMS_DIR)/%.tex: $(POEMS_DIR)/%.md
	$(md_to_tex_path) $(POEMS_DIR)/$*.md $@

all: $(TARGETS:=.html) $(TARGETS:=.epub) $(TARGETS:=.azw3)

$(ILLUST_DIR)/%.eps: $(ILLUST_DIR)/%.svg
	inkscape -z -f $< -E $@

$(ILLUST_DIR)/%.eps: $(ILLUST_DIR)/%.jpg
	convert $< eps2:$@

%.html: %.tex $(IMAGES) $(INDIV_POEMS) $(INCLUDEDTEX) ebook_builder.sh
	sh ebook_builder.sh -o $@ $(EBOOK_BUILDER_ARGS)

%.epub: %.tex $(IMAGES) $(INDIV_POEMS) $(INCLUDEDTEX) ebook_builder.sh $(POETRY_STYLESHEET)
	sh ebook_builder.sh -o $@ --cover $(COVER) --style $(POETRY_STYLESHEET) $(EBOOK_BUILDER_ARGS)

%.azw3: %.epub ebook_builder.sh
	kindlegen $< -o $@

