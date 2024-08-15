#usr/bin/env bash



# Clean up by aborting the rebase and deleting the new branch if there
# has been an error.
set -e

cleanup() {
    echo "Performing cleanup..."
    if git branch --list | grep -q "$new_branch"; then
        git rebase --abort || true
        git checkout "$target_branch"
        git branch -D "$new_branch"
    fi
}

trap cleanup EXIT


# Check arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  echo "Usage: $0 <upstream_remote> <target_branch> <crowdin_branch> <language_code>"
  exit 1
fi

upstream_remote=$1
target_branch=$2
crowdin_branch=$3
language_code=$4

script_location=$(dirname "$0")

# Make sure target branch is up to date with upstream
git checkout $target_branch
git fetch $upstream_remote
git merge --ff-only "${upstream_remote}/${target_branch}"

# Make sure l10n_main is up to date
git checkout $crowdin_branch
git merge --ff-only "${upstream_remote}/${crowdin_branch}"

# Generate a timestamp for use in branch name
timestamp=$(date +%Y_%m_%d_%H_%M_%S)

# Checkout a new branch for these translations
new_branch="${crowdin_branch}_${language_code}_${timestamp}"
git checkout -b $new_branch

# Perform scripted interactive rebase, taking only commits
# for the language of interest.
GIT_SEQUENCE_EDITOR="f() {
    filename=\$1
    python3 -c \"
import sys
sys.path.insert(0, '$script_location')
from git_tools import filter_commits

filter_commits('\$filename', '$language_code')
\"
}; f" git rebase -i "$target_branch"

# Remove the trap if the rebase succeeds. No clean up is necessary.
trap - EXIT
