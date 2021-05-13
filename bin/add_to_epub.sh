#!/bin/bash -e
epub="${1}"
full_epub="$(realpath "${epub}")"
shift
test -f "${epub}" || exit 1
files_to_include=( )
for file in "$@";do
	test -f "${file}" && files_to_include+=( "${file}" )
done
test "${#files_to_include[@]}" -eq 0 && return 0
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
		\\t<item id=\"$(basename "${file}" | tr . _)\" href=\"${file}\" media-type=\"${mime}\" />\
" "${tmpdir}/EPUB/content.opf"
done
cd "${tmpdir}"
zip -Xr9D "${full_epub}" -- mimetype *
cd -
rm -r "${tmpdir}"
