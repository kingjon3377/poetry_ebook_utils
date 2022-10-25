#!/bin/bash -e
# Add a file to an EPUB, including adding it to the manifest in content.opf. If
# the EPUB doesn't exist fails with an error, but silently succeeds if no files
# to add provided (and silently discards any nonexistent files provided on the
# command line)
# TODO: Write test(s) of this script
DEBUG_ON=false
usage() {
	echo "Usage: add_to_epub.sh [--debug|--no-debug] ebook.epub file_to_add.ext [addl_file.ext ...]" 1>&2
}
debug_print() {
	test "${DEBUG_ON:-false}" = true && echo "$@" 1>&2
}

epub=
epub_defined=false
files_to_include=( )
for arg in "$@";do
	if test "${arg}" = "--debug"; then
		DEBUG_ON=true
	elif test "${arg}" = "--no-debug"; then
		DEBUG_ON=false
	elif test "${epub_defined:-false}" != true -a -z "${epub}"; then
		epub="${arg}"
		epub_defined=true
	elif test -f "${arg}"; then
		files_to_include+=( "${arg}" )
	else
		debug_print "File ${arg} not found"
	fi
done
if test "${epub_defined:-false}" != true -o -z "${epub}"; then
	usage
	exit 1
elif !  test -f "${epub}";then
	echo "EPUB file ${epub} does not exist" 1>&2
	usage
	exit 1
elif test "${#files_to_include[@]}" -eq 0; then
	debug_print "No files to add"
	exit 0
fi
full_epub="$(realpath "${epub}")"
tmpdir=$(mktemp -d)
unzip -d "${tmpdir}" "${epub}"
cp "${files_to_include[@]}" "${tmpdir}/EPUB"
for file in "${files_to_include[@]}";do
	if test "${file}" = page-map.xml; then
		mime=application/oebps-page-map+xml
	else
		mime=$(file --mime-type "${file}")
	fi
	sed -i -e "/\\/manifest/i \
		<item id=\"$(basename "${file}" | tr . _)\" href=\"${file}\" media-type=\"${mime}\" />\
" "${tmpdir}/EPUB/content.opf"
done
(
cd "${tmpdir}"
zip -Xr9D "${full_epub}" -- mimetype *
)
rm -r "${tmpdir}"
