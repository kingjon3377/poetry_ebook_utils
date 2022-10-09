#!/bin/bash -e
# Add a file to an EPUB, including adding it to the manifest in content.opf. If
# the EPUB doesn't exist fails with an error, but silently succeeds if no files
# to add provided (and silently discards any nonexistent files provided on the
# command line)
usage() {
	echo "Usage: add_to_epub.sh ebook.epub file_to_add.ext [addl_file.ext ...]" 1>&2
}
if ! test $# -ge 1; then
	usage
	exit 1
fi
epub="${1}"
full_epub="$(realpath "${epub}")"
shift
if !  test -f "${epub}";
	echo "EPUB file ${epub} does not exist" 1>&2
	usage
	exit 1
fi
files_to_include=( )
# TODO: support a "verbose debug" mode that logs if a specified file doesn't exist
for file in "$@";do
	test -f "${file}" && files_to_include+=( "${file}" )
done
test "${#files_to_include[@]}" -eq 0 && exit 0
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
