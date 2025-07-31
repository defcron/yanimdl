#!/bin/bash
# Get images from a search response json (or several).

yanimdl_main() {
    if [ $# -lt 1 ]; then
        echo "usage: $0 <results-input-file-1.json> [results-input-file-2.json]... [results-input-file-N.json]"
        return 1
    fi

    TIMESTAMP=$(date -u +%s%N)
    JQ_FILTER_1_ENTITIES=".blocks[1].params.adapterData.serpList.items.entities"
    JQ_FILTER_2_ORIG_URL=".[].origUrl"
    JQ_FILTER_2_PREVIEW_URL=".[].viewerData.preview.[].url"
    JQ_FILTER_2_DUPS_URL=".[].viewerData.dups.[].url"
    PAGE_NUMBER=${PAGE_NUMBER:-1}
    URL_FILES_FILENAME_PREFIX="$1"
    URL_FILES_FILENAME_SUFFIX="$PAGE_NUMBER"
    DEDUP_FILES_FILENAME_SUFFIX=".dedup.txt"
    ORIG_URL_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.origUrl.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
    PREVIEW_URLS_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.preview-urls.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
    DUPS_URLS_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.dups-urls.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
    ALL_URLS_FILE_PATH="${URL_FILES_FILENAME_PREFIX}.urls.all.${TIMESTAMP}.${URL_FILES_FILENAME_SUFFIX}.txt"
    JSON_OUTPUT_FILE_PATH=${@}
    YANIMDL_DL_COMMAND_OUTPUT_LOG_FILE_PATH="yanimdl.dl.log.txt"

    for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq "${JQ_FILTER_1_ENTITIES}${JQ_FILTER_2_ORIG_URL}"); do printf "%s\n" "$i" | jq -r; done | tee -a "${ORIG_URL_FILE_PATH}"

    cat "${ORIG_URL_FILE_PATH}" | sort -u | tee "${ORIG_URL_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}"
    cat "${ORIG_URL_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}" | tee -a "${ALL_URLS_FILE_PATH}"

    for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq "${JQ_FILTER_1_ENTITIES}${JQ_FILTER_2_PREVIEW_URL}"); do printf "%s\n" "$i" | jq -r; done | tee -a "${PREVIEW_URLS_FILE_PATH}"

    cat "${PREVIEW_URLS_FILE_PATH}" | sort -u | tee "${PREVIEW_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}"
    cat "${PREVIEW_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}" | tee -a "${ALL_URLS_FILE_PATH}"

    for i in $(cat ${JSON_OUTPUT_FILE_PATH} | jq "${JQ_FILTER_1_ENTITIES}${JQ_FILTER_2_DUPS_URL}"); do printf "%s\n" "$i" | jq -r; done | tee -a "${DUPS_URLS_FILE_PATH}"

    cat "${DUPS_URLS_FILE_PATH}" | sort -u | tee "${DUPS_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}"
    cat "${DUPS_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}" | tee -a "${ALL_URLS_FILE_PATH}"

    cat "${ALL_URLS_FILE_PATH}" | sort -u | tee -a "${ALL_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}"

    # Claude made this downloader script: yanimdl.dl.sh needs to be in your $PATH (and so does this yanimdl.sh file we're in here now too)
    if [ -f "./yanimdl.dl.sh" ]; then
        YANIMDL_DL_COMMAND="./yanimdl.dl.sh"
    else
        YANIMDL_DL_COMMAND="yanimdl.dl.sh"
    fi

    echo "YANIMDL_DL_COMMAND=\"${YANIMDL_DL_COMMAND}\""

    $YANIMDL_DL_COMMAND download "${ALL_URLS_FILE_PATH}${DEDUP_FILES_FILENAME_SUFFIX}" | tee -a "${YANIMDL_DL_COMMAND_OUTPUT_LOG_FILE_PATH}"

    ## Alternate lightweight downloader. you can comment out the line above and uncomment the next line below here if you prefer a simple self-contained downloader, but this one here is going to be slow, and likely will have other issues which make it a non-optimal solution. Good for simple testing though if needed.
    #for i in $(cat "${ORIG_URL_FILE_PATH}.dedup.txt" "${PREVIEW_URLS_FILE_PATH}.dedup.txt" "${DUPS_URLS_FILE_PATH}.dedup.txt"); do wget -T 30 --max-redirect=30 --trust-server-names --retry-on-host-error "$i"; done | tee "${YANIMDL_DL_COMMAND_OUTPUT_LOG_FILE_PATH}"

    # Add proper file extensions to all received items.
    exiftool '-filename<%f%-c.$filetypeextension' -ext '*' . | tee -a "${YANIMDL_DL_COMMAND_OUTPUT_LOG_FILE_PATH}"

    # Delete all exact duplicates.
    fdupes -dN . | tee -a "${YANIMDL_DL_COMMAND_OUTPUT_LOG_FILE_PATH}"

    return 0
}

yanimdl_main "$@"

