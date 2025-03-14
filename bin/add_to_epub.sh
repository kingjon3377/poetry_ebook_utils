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

mime_type_for() {
    case "$1" in
        page-map.xml) echo 'application/oebps-page-map+xml' ;;
        *.xhtml) echo 'application/xhtml+xml' ;;
        *) file --brief --mime-type "$1" ;;
    esac
}

add_to_manifest_sed() {
	sed -i -e "/\\/manifest/i \
		<item id=\"$(basename "${1}" | tr . _)\" href=\"${1}\" media-type=\"${2}\" />\
" "${tmpdir}/EPUB/content.opf"
}

add_to_manifest_xmlstarlet() {
    path="package/manifest/item[@href='${1}']"
    file="${tmpdir}/EPUB/content.opf"
    existing=$(xml sel -t -v "${path}" "${file}")
    if test -n "${existing}";then
        xml ed --inplace -u "${path}/@media-type" -v "${2}" "${file}"
    else
        # Adapted from https://stackoverflow.com/a/65996318
        # shellcheck disable=SC2016
        xml ed -s "package/manifest" -t elem --name "item" --var new_node '$prev' \
            --insert '$new_node' --type attr --name id --value "$(basename "${1}" | tr . _)" \
            --insert '$new_node' --type attr --name href --value "${1}" \
            --insert '$new_node' --type attr --name media-type --value "${2}" \
            "${file}"
    fi
}

add_to_manifest() {
    if command -v xml >/dev/null 2>&1; then
        add_to_manifest_xmlstarlet "$@"
    else
        add_to_manifest_sed "$@"
    fi
}

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
    mime="$(mime_type_for "$file")"
	debug_print "Adding ${file} to manifest as ${mime}"
    add_to_manifest "${file}" "${mime}"
done
(
cd "${tmpdir}"
zip -Xr9D "${full_epub}" -- mimetype *
)
rm -r "${tmpdir}"
