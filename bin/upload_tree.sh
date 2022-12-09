#!/bin/bash

shopt -s globstar

function usage() {
    echo "$0 <cert_store> <src>"
    echo "- Upload a tree of files via http PUT."
    echo
    echo "  cert_store - Where to find keys and certificates for client SSL "
    echo "               authentication. Files should be named '<hostname>.key' "
    echo "               '<hostname>.pem', where 'hostname' is the short hostname "
    echo "               of the machine (foo.bar.gov would have key 'foo.key')."
    echo "  src - The source directory to upload, recursively."
    echo
    exit 1
}

function error() {
    echo "$1"
    exit 1
}

SENT=0
SKIPPED=0

function upload_file() {
    local cert=$1
    local key=$2
    local path=$3

    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY

    local args=(--connect-timeout 1)

    local up_dest="${DEST_SERVER}/${UP_PATH}/${path}"
    local down_path="${DEST_SERVER}/${DOWN_PATH}/${path}"

    log=$(mktemp)

    if ! curl "${args[@]}" -f --head "$down_path" >> "$log" 2>&1; then
        echo "Uploading ${path}"
        if ! curl -f "${args[@]}" --key "$key" --pass "$host" \
             -E "$cert" -T "$path" "${up_dest}" >> "$log" 2>&1; then
            error "Error sending file $path. See $log."
        fi
        SENT=$(( SENT + 1 ))
    else
        SKIPPED=$(( SKIPPED + 1 ))
    fi
}

DEST_SERVER=https://pe-serve.lanl.gov
# The upload and download paths are different, as the upload path requires
# certificate auth, while the download path does not.
UP_PATH=upload
DOWN_PATH=put/upload

function main() {

    local cert_store=$1
    local src_path=$2

    # Strip the full domain name from the host.
    host=$(hostname -s)

    cert_file=${cert_store}/${host}.pem
    key_file=${cert_store}/${host}.key

    if [[ -z ${cert_store} ]] || [[ -z $src_path ]]; then
        usage
    fi

    if ! [[ -e $cert_file ]]; then
        error "Could not find cert file at $cert_file"
    elif ! [[ -e $key_file ]]; then
        error "Could not find key file at $key_file"
    elif ! [[ -e $src_path ]]; then
        error "Source path '${src_path}' does not exist."
    fi
    
    # Move into the root of what we're moving.
    pushd "$src_path" || exit 1
    echo "Uploading to ${DEST_SERVER}"

    for file in **/*; do 
        if [[ $file == "**/*" ]]; then
            # There's nothing to upload.
            break
        fi    

        # Don't send directories
        if [[ -d "$file" ]]; then
            continue;
        fi

        # Upload the file (remove the leading './')
        upload_file "$cert_file" "$key_file" "${file#./}"
    done

    local total=$(( SENT + SKIPPED ))
    if [[ "$total" -eq 0 ]]; then
        echo "Nothing to upload"
    else
        echo "Sent $SENT/$total $(( (SENT * 100) / total ))%"
        echo "Skipped $SKIPPED/$total $(( (SKIPPED * 100) / total ))%"
    fi
}

main "$1" "$2" "$3"
