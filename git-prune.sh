#!/bin/bash

git-prune() {
  git fetch --all

  PRUNE_DAYS=30
  PRUNE_BEFORE=$(date -Iseconds -v-${PRUNE_DAYS}d)
  
  # Use %(HEAD) and sed to exclude the mainline
  BRANCHES_LIST=$(git branch \
    --list \
    --format='%(HEAD) %(refname:lstrip=2) %(upstream:lstrip=2)' \
    | sed -nE 's/  (.+)/\1/gp')

  # Loop through all branches, to find branches which have
  # not been modified in the past 30d
  PRUNABLE=()
  while IFS= read -r branchline || [[ -n $branchline ]]; do
    local_ref="${branchline% *}"
    remote_ref="${branchline#* }"

    prune_ref="${remote_ref}"
    if [[ -z "$prune_ref" ]]; then
      prune_ref="${local_ref}"
    fi

    LOG_OUT=$(git log \
      --oneline \
      -n 1 \
      --since="${PRUNE_BEFORE}" \
      "${prune_ref}" \
      --)

    if [[ -z "$LOG_OUT" ]]; then
      PRUNABLE+=("${local_ref}")
    fi
  done < <(printf '%s' "$BRANCHES_LIST")

  # Use FZF to pick branches to prune
  TO_PRUNE=$(printf "%s\n" "${PRUNABLE[@]}" \
    | fzf \
      -m \
      --layout=reverse \
      --border=rounded \
      --header="Branches to prune" \
      --header-first \
      --prompt="Use tab to select more than one " \
      --preview='echo "{} commit history"; echo; git log --no-patch --format="format:%cr (%aN)%n%s%n" {}' \
      --preview-label='Latest Commit' \
      --preview-window=wrap)

  if [[ -z "$TO_PRUNE" ]]; then
    exit
  fi

  while IFS= read -r branch || [[ -n $branch ]]; do
    git branch -D "${branch}"
  done < <(printf '%s' "$TO_PRUNE")
}

git-prune
