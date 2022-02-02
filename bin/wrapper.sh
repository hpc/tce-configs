#!/bin/bash

set -e

export REPO_ROOT
REPO_ROOT=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")

# shellcheck disable=1090
. "$1" "$2"
exit $?
