#!/bin/bash

REPO_ROOT=$(dirname $(dirname $(readlink -f ${BASH_SOURCE[0]})))

echo ${REPO_ROOT}

failed=
for file in ${REPO_ROOT}/bin/*.sh releases/*/environments/*/*.sh; do 
    echo -n " Checking $file"
    shellcheck -x --source-path=SCRIPTDIR $file
    if ! [[ $? -eq 0 ]]; then
        failed=true
    else
        echo " OK"
    fi
done

if [[ -n $failed ]]; then
    exit 1
fi
