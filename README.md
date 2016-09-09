This project provides a significant portion of the apparatus for producing a
collection of poetry in PDF, EPUB, and AZW3 (Kindle) formats from mixed (La)TeX
(for front- and back-matter) and Markdown (for the poems) sources. It requires
either [`poetrytex`](https://bitbucket.org/SamWhited/poetrytex) or
[`poemscol`](https://www.ctan.org/pkg/poemscol) (define `POETRYTEX` or
`POEMSCOL`, then include `poemscompat.tex`), and also
[`pdflatex-makefile`](https://github.com/ransford/pdflatex-makefile) (set the
location of the Makefile fragment that project provides to `PDFLATEX_MAKEFILE`
before including `distrib.mk`).

In addition to one set of commands that can use either `poemscol` or
`poetrytex`, this project contains a command (not original to me) to let an
image use up the rest of the current page, but not overflow to the next.
