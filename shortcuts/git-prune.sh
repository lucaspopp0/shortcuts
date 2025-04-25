#!/bin/bash

git-prune() {
  HELP=false
  PRUNE_DAYS=30
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        HELP=true
        shift # past flag
        ;;
      -d|--days)
        PRUNE_DAYS="$2"
        shift # past flag
        shift # past value
        ;;
      -*|--*)
        echo "Unknown option $1"
        exit 1
        ;;
    esac
  done

  if [[ "$HELP" == "true" ]]; then
    echo ""
    printf '  \033[1m%s\033[0m\n' "git-prune"
    echo ""
    printf '    %s\n' "Prune branches which had their upstream deleted, or have"
    printf '    %s\n' "not been touched in a while"
    echo ""
    printf '  \033[1m%s\033[0m %s\n' "Usage:" "git-prune [options]"
    echo ""
    printf '  \033[1m%s\033[0m\n' "Options:"
    echo ""
    printf '    %s\n' "-d, --days    Threshold for how many days of inactivity"
    printf '    %s\n' "              before a branch becomes \"stale\""
    printf '    %s\n' "              (default: 30)"
    echo ""
    printf '    %s\n' "-h, --help    Display help text"
    echo ""
    return
  fi

  echo "Fetching remotes..."
  
  git fetch -q \
    --all \
    --prune

  PRUNE_BEFORE=$(date -Iseconds -v-${PRUNE_DAYS}d)
  
  # Use %(HEAD) and sed to exclude the mainline
  BRANCHES_LIST=$(git branch \
    --list \
    --format='%(HEAD) %(refname:lstrip=2)' \
    | sed -nE 's/  (.+)/\1/gp')

  echo "Searching for branches not touched in the last ${PRUNE_DAYS}d..."

  # Loop through all branches, to find branches which have
  # not been modified in the past 30d
  PRUNABLE=()
  while IFS= read -r branch || [[ -n $brancbranchhline ]]; do
    LOG_OUT=$(git log \
      --oneline \
      -n 1 \
      --since="${PRUNE_BEFORE}" \
      "${branch}" \
      --)

    if [[ -z "$LOG_OUT" ]]; then
      PRUNABLE+=("${branch} (stale)")
    fi
  done < <(printf '%s' "$BRANCHES_LIST")

  echo "Searching for branches with deleted upstreams..."

  prunable_contains() {
    printf '%s\0' "${PRUNABLE[@]}" | grep -F -x -z -- "$1"
  }
  
  # Add branches with deleted upstreams to the list
  UPSTREAMS_DELETED=$(git for-each-ref \
    --format '%(refname:short) %(upstream:track)' \
    refs/heads \
    | sed -nE 's/(.+) \[gone\]/\1/p')

  while IFS= read -r branch || [[ -n $brancbranchhline ]]; do
    if [[ -z $(prunable_contains "$branch (stale)") ]]; then
      PRUNABLE+=("${branch} (upstream gone)")
    fi
  done < <(printf '%s' "$UPSTREAMS_DELETED")

  if [[ "${#PRUNABLE[@]}" == 0 ]]; then
    echo "No branches to prune"
    return
  fi

  HEADER_LINES=(\
    "Press ctrl-c to cancel" \
    "Press ctrl-a to select all" \
    "Press tab to select more than one" \
  )

  FZF_HEADER=$(printf "%s\n" "${HEADER_LINES[@]}")
  FZF_PRUNABLES=$(printf "%s\n" "${PRUNABLE[@]}" | sort -r)

  # Use FZF to pick branches to prune
  TO_PRUNE=$(printf '%s\n%s\n' "$FZF_HEADER" "$FZF_PRUNABLES" \
    | fzf \
      --multi \
      --bind ctrl-a:select-all \
      --border=rounded \
      --header-lines="${#HEADER_LINES[@]}" \
      --header-first \
      --prompt="Branches to prune: " \
      --preview='export BRANCH={};
                  export BRANCH="${BRANCH% \(*}";
                  echo -e "\033[1m$BRANCH\033[0m";
                  echo; 
                  git log --no-patch --format="format:%cr (%aN)%n%s%n" "${BRANCH}" --' \
      --preview-label='Commit History' \
      --preview-window=wrap)

  if [[ -z "$TO_PRUNE" ]]; then
    echo "Operation cancelled"
    return
  fi

  PRUNE_ARR=()
  while IFS= read -r branch || [[ -n $branch ]]; do
    PRUNE_ARR+=("${branch% \(*}")
  done < <(printf '%s' "$TO_PRUNE")

  echo "Cleaning up ${#PRUNE_ARR[@]} branches..."
  for branch in "${PRUNE_ARR[@]}"; do
    git branch -D "${branch}"
  done
}

# Configure bash completion
if which complete 2>&1 > /dev/null; then
  complete \
    -W '-h --help -d --days' \
    git-prune
fi
