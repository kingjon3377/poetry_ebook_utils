# Makefile fragment for the Poetry Ebook Utilities.
#
# Copyright 2013-2016 Jonathan Lovelace
#
# This project may be distributed and/or modified under the conditions of the
# LaTeX Project Public License, either version 1.3c of this license or (at your
# option) any later version. The latest version of this license is in:
#
# http://www.latex-project.org/lppl.txt
#
# and version 1.3c or later is part of all distributions of LaTeX version
# 2008/05/04 or later.
#
# Maintainer: Jonathan Lovelace
# Website:    https://shinecycle.wordpress.com
# Contact:    kingjon3377@gmail.com
#
# This work consists of this Makefile fragment (distrib.mk), README.md, and the
# two shell scripts (md2tex.sh and ebook_builder.sh) in bin/. It is distributed
# with poemscompat.tex, also under the LPPL; a small snippet (helpers.tex)
# under the CC-BY-SA 3.0, and a sample CSS file.

# Depends on pdflatex-makefile, found at
# https://github.com/ransford/pdflatex-makefile, for building PDF; pass its
# location in the PDFLATEX_MAKEFILE variable.

# Other variables you should define, other than those required by pdflatex-makefile:
# $(POEMS_DIR): The directory containing the individual poem files in Markdown format.
# $(ILLUST_DIR): The directory containing images included in the book
# $(EBOOK_BUILDER_ARGS): Any general arguments to pass to ebook_builder.sh
# $(COVER): The path to and filename of the cover image
# $(POETRY_STYLESHEET): The path to and filename of the CSS stylesheet you want
#                       the EPUB and Kindle versions to use, if the stylesheet
#                       included with this package does not suit your needs.
# $(ILLUST_FROM_SVG): The list of images (under $(ILLUST_DIR), but including
#                     that prefix in each one) to regenerate from SVG.

distrib_mk_path := $(lastword $(MAKEFILE_LIST))
%: $(distrib_mk_path)
include $(PDFLATEX_MAKEFILE)

ifneq ($(QUIET),)
kindle_filter	:= grep -v '^Info'
md_to_tex_arg	:=
define svg-to-pdf
	rsvg-convert -f pdf -o $(1) $(2)
endef
else
kindle_filter	:= cat
md_to_tex_arg	:= --verbose
define svg-to-pdf
	echo rsvg-convert -f pdf -o $(1) $(2) && rsvg-convert -f pdf -o $(1) $(2)
endef
endif

ifneq (, $(shell which ack))
grep_func := ack --type=tex --type=make --type=markdown
else
grep_func := grep -r --binary-files=without-match
endif

ifneq (, $(shell which kindlegen))
define to-kindle
	kindlegen $(1) -o $(2) | $(kindle_filter)
endef
else
define to-kindle
	ebook-convert $(1) $(2) | $(kindle_filter)
endef
endif

md_to_tex_path := $(dir $(abspath $(distrib_mk_path)))/bin/md2tex.sh
ebook_builder_path := $(dir $(abspath $(distrib_mk_path)))/bin/ebook_builder.sh
add_to_epub_path := $(dir $(abspath $(distrib_mk_path)))/bin/add_to_epub.sh
# We define TEXINPUTS to ensure that poemscompat.tex can be found without
# having to put its absolute or relative path into the book's source.
export TEXINPUTS:=.:$(dir $(abspath $(distrib_mk_path))):$(TEXINPUTS)

.PHONY: diff all check-fixmes
diff: $(PDFTARGETS)
	echo $(foreach T,$(PDFTARGETS:.pdf=),$(T).old.pdf $(T).pdf ) | xargs -P 2 -n 2 diffpdf

MDTARGETS = $(TARGETS:=.md)
EPUBTARGETS = $(TARGETS:=.epub)
KINDLE_TARGETS = $(TARGETS:=.azw3)
HTMLTARGETS = $(TARGETS:=.html)

INDIV_POEMS:=$(patsubst %.md,%.tex,$(wildcard $(POEMS_DIR)/*.md))
SVG_IMAGES:=$(wildcard $(ILLUST_DIR)/*.svg)
JPG_IMAGES:=$(wildcard $(ILLUST_DIR)/*.jpg)
# TODO: support other formats
IMAGES:=$(SVG_IMAGES) $(JPG_IMAGES)
EPS_IMAGES:=$(SVG_IMAGES:.svg=.eps) $(JPG_IMAGES:.jpg=.eps)

TEX4HTEXTS:=4tc 4ct 4cc css dvi idv lg tmp xref
METAD_EXTS:=top ctn idx ilg ind
POETRY_STYLESHEET:=$(dir $(abspath $(distrib_mk_path)))/poetry_ebook.css

EXTRACLEAN += $(filter-out %.pregen.tex,$(INDIV_POEMS)) $(EPS_IMAGES) texput.log $(ILLUST_FROM_SVG)
EXTRACLEAN += $(foreach EXT,$(TEX4HTEXTS),$(TARGETS:=.$(EXT)))
EXTRACLEAN += $(foreach EXT,$(METAD_EXTS),$(TARGETS:=.$(EXT)))
EXTRACLEAN += titles.idx titles.ilg titles.ind
EXTRADISTCLEAN += $(TARGETS:=.html) $(TARGETS:=.epub) $(TARGETS:=.azw3)

# Files to add to the EPUB after it is created.
EPUB_ADDENDA = page-map.xml

$(ILLUST_DIR)/%.pdf: $(ILLUST_DIR)/%.svg
	@$(call svg-to-pdf,$@,$<)

$(POEMS_DIR)/%.pregen.tex:
	true

# FIXME: The dependency on the pregen file if present doesn't seem to work, so
# the user has to 'make clean' every time a pregen file is created, changed, or
# removed.
$(POEMS_DIR)/%.tex: $(filter-out %.pregen.md,$(POEMS_DIR)/%.md) $($(wildcard $(POEMS_DIR)/%.pregen.tex))
	@echo "Regenerating $@"
	@$(md_to_tex_path) $(md_to_tex_arg) $(POEMS_DIR)/$*.md $@

all: $(TARGETS:=.html) $(TARGETS:=.epub) $(TARGETS:=.azw3)

$(ILLUST_DIR)/%.eps: $(ILLUST_DIR)/%.svg
	inkscape -z -f $< -E $@

$(ILLUST_DIR)/%.eps: $(ILLUST_DIR)/%.jpg
	convert $< eps2:$@

COMMON_INCLUSIONS=$(wildcard *.tex) $(IMAGES) $(INDIV_POEMS) $(INCLUDEDTEX)

$(MDTARGETS): $(COMMON_INCLUSIONS) $(INCLUDED_MD) $(ebook_builder_path) check-fixmes
	bash $(ebook_builder_path)  $(EBOOK_BUILDER_ARGS) -o $@

$(HTMLTARGETS): $(COMMON_INCLUSIONS) $(INCLUDED_MD) $(ebook_builder_path) check-fixmes
	bash $(ebook_builder_path) -o $@ $(EBOOK_BUILDER_ARGS)

$(PDFTARGETS): $(COMMON_INCLUSIONS) $(filter %.pdf,$(ILLUST_FROM_SVG)) check-fixmes

check-fixmes:
	@$(grep_func) FIXME . || true
	@$(grep_func) TODO . || true

%.epub: $(COMMON_INCLUSIONS) $(INCLUDED_MD) $(EPUB_INCLUSIONS) $(ebook_builder_path) $(POETRY_STYLESHEET) $(add_to_epub_path)
	bash $(ebook_builder_path) -o $@ --cover $(COVER) --style $(POETRY_STYLESHEET) $(EBOOK_BUILDER_ARGS)
	sh $(add_to_epub_path) $@ $(EPUB_ADDENDA)

%.azw3: %.epub
	@$(call to-kindle,$<,$@)

%: Makefile

all_images: $(ILLUST_FROM_SVG)

.PHONY: all_images
