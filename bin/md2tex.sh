#!/bin/sh
# Converts a poem in Markdown format to LaTeX (using poemscompat)
#
# Copyright 2013-2016 Jonathan Lovelace
#
# This project may be distributed and/or modified under the conditions of the
# LaTeX Project Public License, either version 1.3c of this license or (at your
# option) any later version. See ../distrib.mk for more details.
#
# Converts a poem in Markdown format, with a nonprinting Unicode character
# marking (if doubled) an incipit or (if not) a first line, to the LaTeX
# dialect that my custom commands adapt to either the poetrytex or the poemscol
# package. Arguments: $1 is the Markdown original; $2 is the TeX file to create.
# Either can be - to indicate standard input or output, respectively
if test $# -ne 2; then
	echo "Usage: md2tex.sh original.md target.tex" 1>&2
	exit 1
fi
handle_output() {
	if test "${1}" = "-"; then
		cat
	else
		cat > "${1}"
	fi
}
# Remove header and footer
sed	"${1}" \
	-e '/^#/d' \
	-e '/\[.*]([^)]*)/d' | \
# Shrink multiple blank lines to just one between paragraphs
sed	-e '/^$/N;/^\n$/D' | \
# Replace end of lines with poetrytex end-of-lines.
sed	-e '1,4s/  $/\\verselinenb/' \
	-e '5,$s/  $/\\verseline/' | \
# Replace a double occurrence of our marker characters, when there is a ! between them, with bangincipit{}
sed	-e 's/￹￹\(.*\)!\(.*\)￻￻/\\bangincipit{\1"!\2}{\1!\2}/g' | \
# Replace a double occurrence of our marker characters with incipit{}.
sed	-e 's/￹￹\(.*\)￻￻/\\incipit{\1}/g' | \
# Replace a single occurrence of our marker characters, when there is a ! between them, with bangfirstline{}
sed	-e 's/￹\(.*\)!\(.*\)￻/\\bangfirstline{\1"!\2}{\1!\2}/g' | \
# Replace a single occurrence of our marker characters with firstline{}.
sed	-e 's/￹\(.*\)￻/\\firstline{\1}/g' | \
# Replace blank lines with stanza markers
sed	-e '1,$s/^$/\\end{stanza}\n\n\\begin{stanza}/' | \
# Get rid of first 'end' and last 'begin'-stanza in file.
sed	-e '1,2d' \
	-e '$d' | \
sed	-e '$d' | \
# Don't put a \verseline or \verselinenb on the last line of a stanza
tr '\n' '\f' | sed -e 's/\\verseline\f\\end{stanza}/\f\\end{stanza}/g' \
		   -e 's/\\verselinenb\f\\end{stanza}/\f\\end{stanza}/g' | tr '\f' '\n' | \
# Fix emphasis
sed	-e 's/_\([^_]*\)_/\\emph{\1}/g' | \
# Translate Markdown quoting to single-line indentation.
sed	-e 's/\(> \|>\)/\\ptind /g' | \
# Translate tabs to eight spaces each. They would be ignored by TeX anyway, if
# not for the next pattern.
sed	-e 's/	/        /g' | \
# Translate four-space substrings to single-line indentation.
sed	-e 's/    /\\ptind /g' | \
# Handle nested (single-inside-double) quotes properly where we can distinguish
# them. Since an apostrophe *should* be used at the beginning of some words, we
# only turn an apostrophe into a left single quote where it is following a
# colon, semicolon, or period. The other thing we fix here is that LaTeX
# by default turns a triple quote into a double quote inside a single quote,
# which is rarely what we want, so we add a non-printing space between them.
# If any of this produces wrong results, either change the script, pre-process
# its input, or post-process its output.
sed -e "s/'\"/'\\\\,\"/g" -e "s/\\([:;\\.]  *\\)'/\\1\`/g" | \
# Fix double-quotes
gawk -F \" -e 'BEGIN { RS = "\0" }' -e "{if((NF-1)%2==0){res=\$0;for(i=1;i<NF;i++){to=\"\`\`\";if(i%2==0){to=\"\\\\'\\\\'\"}res=gensub(\"\\\"\", to, 1, res)};print res}else{print}}" | \
# Strip off all trailing empty lines?
sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' | handle_output "${2}"
