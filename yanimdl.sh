#!/bin/bash
# Get images from a search response json (or several).

if [ $# -lt 1 ]; then
    echo "usage error"
    exit 1
fi

TIMESTAMP=$(date -u +%s%N)
PAGE_NUMBER=${PAGE_NUMBER:-1}
URL_FILES_FILENAME_PREFIX="$1"
URL_FILES_FILENAME_SUFFIX="$PAGE_NUMBER"
ORIG_URL_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.origUrl.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
PREVIEW_URLS_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.preview-urls.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
DUPS_URLS_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.dups-urls.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
JSON_OUTPUT_FILE_PATH="$@"

## Broken. Claude made this: yanimdl.metdatcat.sh has to be in your $PATH
#yanimdl.metdatcat.sh "${URL_FILES_FILENAME_PREFIX}" "$(basename \"$(echo $PWD)\")"

for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq '.blocks[1].params.adapterData.serpList.items.entities.[].origUrl'); do printf "%s\n" "$i" | jq -r | tee -a "${ORIG_URL_FILE_PATH}"; done

cat "${ORIG_URL_FILE_PATH}" | sort | uniq | tee "${ORIG_URL_FILE_PATH}.dedup.txt"

for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq '.blocks[1].params.adapterData.serpList.items.entities.[].viewerData.preview.[].url'); do printf "%s\n" "$i" | jq -r | tee -a "${PREVIEW_URLS_FILE_PATH}"; done

cat "${PREVIEW_URLS_FILE_PATH}" | sort | uniq | tee "${PREVIEW_URLS_FILE_PATH}.dedup.txt"

for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq '.blocks[1].params.adapterData.serpList.items.entities.[].viewerData.dups.[].url'); do printf "%s\n" "$i" | jq -r | tee -a "${DUPS_URLS_FILE_PATH}"; done

cat "${DUPS_URLS_FILE_PATH}" | sort | uniq | tee "${DUPS_URLS_FILE_PATH}.dedup.txt"

# Claude made this downloader script: yanimdl.dl.sh needs to be in your $PATH (and so does this yanimdl.sh file we're in here now too)
yanimdl.dl.sh download "${ORIG_URL_FILE_PATH}.dedup.txt" "${PREVIEW_URLS_FILE_PATH}.dedup.txt" "${DUPS_URLS_FILE_PATH}.dedup.txt"

#for i in $(cat "${ORIG_URL_FILE_PATH}.dedup.txt" "${PREVIEW_URLS_FILE_PATH}.dedup.txt" "${DUPS_URLS_FILE_PATH}.dedup.txt"); do wget -T 30 --max-redirect=30 --trust-server-names --retry-on-host-error "$i"; done

exiftool '-filename<$filename%-c.$filetypeextension' -ext '*' .
fdupes -dN .

## Broken. Claude made this:
#yanimdl.metdatcat.sh finish "${URL_FILES_FILENAME_PREFIX}.json"

exit 0
