#/bin/bash

SCRIPT_DIR=$(dirname "$0")

source "${SCRIPT_DIR}/git-prune.sh"

if which complete 2>&1 > /dev/null; then
  "${SCRIPT_DIR}"/completion.sh
fi
