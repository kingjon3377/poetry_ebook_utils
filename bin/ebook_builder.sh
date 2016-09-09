#!/bin/bash
# Produces an ebook version of the poetry book, as HTML or EPUB.

# Any line in a poem file matching a pattern in EXCLUDE_PATTERNS will be
# filtered out.
EXCLUDE_PATTERNS=( )
# "front matter" is the stuff at the front of the book before the poems, such
# as the title, author, dedication, and preface.
FRONTMATTER=( )
# "back matter" is material at the end of the book after the poems, such as any
# acknowledgements and the about-the-author section. Files can be TeX or
# Markdown.
BACKMATTER=( )
# Arguments that are not immediately following one of the options we handle are
# assumed to hold (possibly after some recursion) the poems and images that
# make up the "main matter."
OTHER_ARGS=( )
COVER=images/cover.jpg
OUTFILE=poems.epub
STYLE=poetry_ebook.css
while test $# -gt 0; do
    case "$1" in
        --exclude) shift; EXCLUDE_PATTERNS+=("${1}"); shift ;;
        --cover) shift; COVER="${1}"; shift ;;
        --out|-o) shift; OUTFILE="${1}"; shift ;;
        --style) shift; STYLE="${1}"; shift ;;
	--front) shift; FRONTMATTER+=("${1}"); shift ;;
	--back) shift; BACKMATTER+=("${1}"); shift ;;
        *) OTHER_ARGS+=("${1}"); shift ;;
    esac
done

pandoc_version=$(pandoc -v | head -n 1 | cut -d' ' -f2)
pandoc_major=${pandoc_version%%.*}
pandoc_minor=${pandoc_version#*.};pandoc_minor=${pandoc_minor%%.*}
echo "pandoc is approximately version ${pandoc_major}.${pandoc_minor}" 1>&2
if test "${pandoc_major}" -ge 2 || ( test "${pandoc_major}" -eq 1 && test "${pandoc_minor}" -ge 16 ) ; then
	pandoc_attribs=true
else
	pandoc_attribs=false
fi

# Returns true if a file exists as a regular file or a link, false otherwise
file_or_link() {
	test -f "${1}" -o -h "${1}"
}

# Include a poem into the ebook
includepoem() {
	if ! file_or_link "${1}" ; then
		echo "Poem ${1} not found" 1>&2
		exit 2
	fi
	sedargs=()
	for pattern in "${EXCLUDE_PATTERNS[@]}"; do
		sedargs+=("-e")
		sedargs+=("/${pattern}/d")
	done
	# Exclude unwanted lines
	sed "${1}" "${sedargs[@]}" | \
	# Use em-dashes where appropriate
	sed -e 's/---/\&mdash;/g' | \
	# Remove the "invisible" marker Unicode character
	sed -e 's/￹//g' -e 's/￻//g' | \
	# Increase the header level (decrease header significance)
	sed -e 's/^## /### /' -e 's/ ##$/ ###/' |
	# Squish consecutive blank lines
	sed -e '/^$/N;/^\n$/D' | \
	# Wrap every non-header line in a verseline-class HTML paragraph
	sed 's@^[^#][^#]*$@<p class="verseline">&</p>@' | \
	# Wrap every non-header paragraph in a stanza-class div
	awk 'BEGIN { RS=""; pretext="<div class=\"stanza\">"; posttext="</div>"; } !/#/ { print pretext; print; print posttext; } /#/ { print }'
	# Add a blank line after the poem.
	echo
}

# Include an SVG, JPEG, or PNG format image into the ebook. If an image with
# the name plus _color, with the same extension, exists, use that instead.
# TODO: Allow specifying alt text and/or image size.
includeimage() {
	if ! file_or_link "${1}" ; then
		echo "Image file ${1} not found" 1>&2
		exit 2
	fi
	case "${1}" in
	*.svg) ext=".svg" base="${1%%.svg}" ;;
	*.jpg) ext=".jpg" base="${1%%.jpg}" ;;
	*.png) ext=".png" base="${1%%.png}" ;;
	esac
	if file_or_link "${base}_color${ext}"; then
		image="${base}_color${ext}"
	else
		image="${1}"
	fi
	if test -n "${2}"; then
		base=${2}
	fi
	if test -z "${3}" && test -z "${4}" || test "${pandoc_attribs}" = false; then
		attrs=""
	elif test -z "${3}"; then
		attrs="{ height=${4} }"
	elif test -z "${4}"; then
		attrs="{ width=${3} }"
	else
		attrs="{ width=${3} height=${4}"
	fi
	# The extra space at the end is to, as per the Pandoc man page, ensure that a caption is not emitted.
	echo "![${base}](${image})${attrs}\ "
	echo
}

# An adapter method to handle including images *or* poems, and multiple files in one call.
includefiles() {
	for file in "$@"; do
		case "${file}" in
		*.svg|*.jpg|*.png) includeimage "${file}" ;;
		*.md) includepoem "${file}" ;;
		*) echo "Unhandled filetype in ${file}" 1>&2 ; exit 2 ;;
		esac
	done
}

# Emit Markdown headers of the right level.
sectionheader() {
	echo "# $* #"
	echo
}
subsectionheader() {
	echo "## $* ##"
	echo
}

# Given the basename of an image, find the preferred filename for inclusion in
# an EPUB. (There may well be a JPEG equivalent of an SVG for use in the PDF,
# for example, but we want to prefer the SVG.)
findimage() {
	base="${1}"
	shift
	if file_or_link "${base}.svg"; then
		includeimage "${base}.svg" "$@"
	elif file_or_link "${base}.png"; then
		includeimage "${base}.png" "$@"
	elif file_or_link "${base}.jpg"; then
		includeimage "${base}.jpg" "$@"
	else
		echo "Image ${1} not found" 1>&2
		exit 2
	fi
}

# Handle a line in the TeX document.
handle_line() {
	if test $# -eq 0; then return; fi
	case "${1}" in
	# When asked to clear the page, emit a div to do that.
	*clearpage*) echo '<div class="clearpage" />' ;;
	*cleardoublepage*) echo '<div class="cleardoublepage" />' ;;
	# Emit equivalent headers for sequence and section titles.
	*sequencetitle*) sectionheader "$(echo "${1}" | sed -e 's/^[ 	]*sequencetitle{\([^}]*\)}[ 	]*$/\1/' \
		-e 's/^[ 	]*\\sequencetitle{\([^}]*\)}[ 	]*$/\1/' )" ;;
	*sequence*sectiontitle*) subsectionheader "$(echo "${1}" | \
			sed -e 's/^[ 	]*sequencefirstsectiontitle{\([^}]*\)}[ 	]*$/\1/' \
				-e 's/^[ 	]*\\sequencefirstsectiontitle{\([^}]*\)}[ 	]*$/\1/' \
				-e 's/^[ 	]*sequencesectiontitle{\([^}]*\)}[ 	]*$/\1/' \
				-e 's/^[ 	]*\\sequencesectiontitle{\([^}]*\)}[ 	]*$/\1/' )" ;;
	# Anytime the TeX includes a file, we want to handle its contents.
	*input*)
		# This is too complicated for shell parameter substitution.
		# shellcheck disable=SC2001
		file="$(echo "${1}" | sed -e 's/^[ 	]*\\input{\([^}]*\)}[ 	]*$/\1.tex/')"
		if ! file_or_link "${file}" ;then
			echo "Input file ${file} not found" 1>&2
			exit 2
		fi
		while read -r line; do handle_line "${line}"; done < "${file}" ;;
	# Handle including poems specially, since their TeX is generated from Markdown.
	*includepoem*) includepoem "$(echo "${1}" | \
			sed -e 's/^[ 	]*\\includepoem{\([^}]*\)}{[^}]*}{[^}]*}{[^}]*}{[^}]*}[ 	]*$/\1.md/' \
				-e 's/^[ 	]*\\includepoem{\([^}]*\)}{\\em{[^}]*}}{[^}]*}{[^}]*}{[^}]*}[ 	]*$/\1.md/')"
			;;
	# When the TeX includes an image, emit equivalent Markdown
	# TODO: Get metadata for scaling from a comment on the line, if there is one.
	*illustration*)
		# This is too complicated for shell parameter substitution.
		# shellcheck disable=SC2001
		findimage "$(echo "${1}" | sed 's/^[ 	]*\\illustration{\([^}]*\)}[ 	]*$/\1/')" "" 90% ;;
	*includegraphics*) echo "${1}" | sed -e 's@^[ 	]*\\includegraphics\[\([^]]*\)\]{\([^}]*\)}[ 	]*$@\2 \1@' \
			-e 's@^[ 	]*\\includegraphics{\([^}]*\)}[ 	]*$@\1@' | { read -r imgname params
		if test -z "${params}"; then
			findimage "${imgname}"
		else
			findimage "${imgname}" $(echo "${params}" | tr ',' '\n' | while read -r param;do
				case "${param}" in
					\\keepaspectratio) : ;;
					\\width=\\textwidth) echo "width=90%" ;;
					\\width=.[0-9]*\\textwidth) echo "${param}" | \
						sed 's@^\\\(width=\)\.\([0-9]*\)\\textwidth$@\1\2%@' ;;
					\\height=\\measurepage) echo "height=90%" ;;
					\\height=.[0-9]*\\measurepage) echo "${param}" | \
						sed 's@^\\\(height=\)\.\([0-9]*\)\\measurepage$@\1\2%@' ;;
					\\width*=|\\height=) echo "${param}" | \
						sed 's@^\\\(width\|height\)\(=[0-9a-z]*\)$@\1\2@'  ;;
				esac; done)
		fi } ;;
	'') : ;;
	%*) echo "<!-- ${1##%} -->" ;;
	'\begin{center}') echo '<div class="centered">' ;;
	'\end{center}') echo '</div>' ;;
	# We *want* literal backslash-literal character sequences.
	\\label*) : ;;
	\\topskip*) : ;;
	\\vspace*) : ;;
	*) { echo -n "Unhandled line:"; for i in "$@";do echo -n " '${i}'";done; echo; } 1>&2 ;;
	esac
}

# Get the front-matter (title, author, dedication, preface) from TeX and turn it into Markdown.
frontmatter() {
	#local preface_file="${2:-preface.tex}"
	# The title and author are in metadata.tex
	grep -h coltitle  "${@}" | sed -n 's:^\\newcommand{\\coltitle}{\([^}]*\)}$:% \1:p'
	grep -h colauthor "${@}" | sed -n 's:^\\newcommand{\\colauthor}{\([^}]*\)}$:% \1:p'

	if grep -q ptdedication "${@}"; then
		echo
		echo '### Dedication ###'
		echo
		for file in "${@}";do
			grep -q ptdedication "${file}" && \
				awk \
					'BEGIN { printing = 0; }
					 /ptdedication/ { printing = 1; next; }
					 printing == 0 { next; }
					 /{/ { printing++; }
					 /}/ { printing--; }
					 { print; }' "${file}" | \
				sed -e 's/\\\\$/  /' \
					-e '/^%/d' \
					-e 's:\\bigskip:<br />:' \
					-e 's/}$//' \
					-e 's/^[ 	]*//'
			echo
		done
	fi

	for file in "$@";do printing=true; while read -r line; do
		case "${line}" in
		\\newcommand*) continue ;;
		\\chapter*) echo "${line}" | sed -e 's@^\\chapter\*{\([^}]*\)}$@# \1 #@' ; continue ;;
		\\addcontentsline*) continue ;;
		%*) continue ;;
		\\renewcommand\*\{\\ptdedication\}\{*) printing=false ; continue ;;
		\\clearpage) continue ;;
		*\}) if test "${printing}" != true; then printing=true; continue; fi ;;
		'') echo; continue ;;
		*) : ;;
		esac
		if test "${printing}" = true; then
			echo "${line}"
		else
			continue
		fi

	done < "${file}"; done | \
	# We want to match literal backquotes, so single quotes disabling their expansion is a feature.
	# shellcheck disable=SC2016
	sed -e 's/\\emph{\([^}]*\)}/_\1_/g' \
		-e 's/``/\&ldquo;/g' \
		-e "s/''/\\&rdquo;/g" \
		-e 's/---/\&mdash;/g'
	echo
}

# Get the back-matter (acknowledgements, illustration sources,
# about-the-author) from TeX and turn it into Markdown
# Some of the back-matter is already Markdown or HTML-fragment; pass it through
# unmodified. The rest is (La)TeX; we cut out the metadata-type TeXisms, and
# turn TeXisms for quotes, emdashes, italics, typewriter text, etc., into
# Markdownisms or HTMLisms; that includes handling for URLs done in
# typewriter-text wrapped in an mbox to keep them on one line, and handling for
# the photo that accompanies the about-the-author biography.
backmatter() {
	for file in "$@";do
		case "${file}" in
		*.md|*.txt|*.htm|*.html) cat "${file}" ; echo ; continue ;;
		*.tex) : ;;
		*) echo "Unexpected backmatter file ${file}" 1>&2; return 3 ;;
		esac
		while read -r line;do
			case "${line}" in
			\\chapter*) echo "${line}" | sed -e 's@^\\chapter\*{\([^}]*\)}$@# \1 #@' ; continue ;;
			\\addcontentsline*) continue ;;
			%*) continue ;;
			\\section*) echo "${line}" | sed -e 's@^\\section\*{\([^}]*\)}$@## \1 ##@' ; continue ;;
			*\\ptgroup*) continue ;;
			\\begin\{wrapfigure\}*) continue ;;
			\\end\{wrapfigure\}*) continue ;;
			\\vspace*) continue ;;
			\\includegraphics*) echo "${line}" | sed 's@^\\includegraphics\[[^]]*\]{\([^}]*\)}$@![Author Photo](\1)@' ;;
			\\clearpage*) continue ;;
			'') echo; continue ;;
			*) echo "${line}" ;;
			esac
		done < "${file}" | sed -e 's/%.*$//' \
			-e 's/``/\&ldquo;/g' \
			-e "s/''/\\&rdquo;/g" \
			-e 's/\\LaTeX{}/LaTeX/g' \
			-e 's/\\textit{\([^}]*\)}/_\1_/g' \
			-e 's/\\texttt{\([^}]*\)}/`\1`/g' \
			-e 's@\\textbf{\([^}]*\)}@**\1**@g' \
			-e 's/\\\\//g' -e 's/\\url{\([^}]*\)}/[\1](\1)/g' \
			-e 's/\\mbox{\([^}]*\)}/\1/g' \
			-e 's/{\\\(small\|footnotesize\)\([^}]*\)}/`\2`/g' \
			-e 's/---/\&mdash;/g' \
			-e 's@~@ @g' \
			-e 's@\\\\@@g'
		echo
	done

	echo
}

# Put everything together. Takes a list of files to parse for the main-matter,
# and uses poems/all.tex if none provided.
markdownbook() {
	frontmatter "${FRONTMATTER[@]}"
	if test $# -eq 0; then
		echo "No main-matter provided!" 1>&2
	fi
	for file in "$@"; do
		cat "${file}"
	done | while read -r line; do
		handle_line "${line}"
	done
	backmatter "${BACKMATTER[@]}"
}
out=${OUTFILE:-poems.epub}
case "${out}" in
*html)
	markdownbook "${OTHER_ARGS[@]}" | sed -e '/^$/N;/^\n$/D' | \
		pandoc -t html -s -o "${out}" --css="${STYLE:-poetry_ebook.css}" ;;
*epub)
	markdownbook "${OTHER_ARGS[@]}" | sed -e '/^$/N;/^\n$/D' | \
		pandoc -t epub -o "${out}" --epub-cover-image="${COVER:-images/cover.jpg}" \
			--epub-stylesheet="${STYLE:-poetry_ebook.css}" ;;
*md) markdownbook "${OTHER_ARGS[@]}" | sed -e '/^$/N;/^\n$/D' > "${out}" ;;
esac