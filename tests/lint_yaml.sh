#!/bin/bash

if ! which yamllint; then
    echo "Could not find yamllint. Install in a python virtual env with pip, and activate that env."
fi

REPO_ROOT=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE}")")")

shopt -s globstar

yamllint --no-warnings -d relaxed ${REPO_ROOT}
