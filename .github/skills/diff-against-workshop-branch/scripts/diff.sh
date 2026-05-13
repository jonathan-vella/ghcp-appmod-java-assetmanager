#!/usr/bin/env bash
# Compare the current working tree against a workshop reference branch
# from https://github.com/Azure-Samples/java-migration-copilot-samples.
#
# Usage:
#   diff.sh <branch-nickname> [path-filter]
#
# branch-nickname: java-upgrade | expected | deployment-expected
# path-filter:     optional pathspec passed to `git diff` (e.g. web/, pom.xml)
#
# This is read-only: it adds a `workshop-upstream` remote (if missing),
# fetches the requested branch, and runs `git diff` against it. It never
# checks out, merges, or rebases.

set -euo pipefail

UPSTREAM_NAME="workshop-upstream"
UPSTREAM_URL="https://github.com/Azure-Samples/java-migration-copilot-samples.git"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <java-upgrade|expected|deployment-expected> [path-filter]" >&2
    exit 2
fi

NICK="$1"
PATH_FILTER="${2:-}"

case "$NICK" in
    java-upgrade)        REF="workshop/java-upgrade" ;;
    expected)            REF="workshop/expected" ;;
    deployment-expected) REF="workshop/deployment-expected" ;;
    *)
        echo "Unknown branch nickname '$NICK'. Expected one of: java-upgrade, expected, deployment-expected" >&2
        exit 2
        ;;
esac

# Locate repo root so we can run from anywhere.
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Add or verify the upstream remote.
if git remote get-url "$UPSTREAM_NAME" >/dev/null 2>&1; then
    EXISTING_URL="$(git remote get-url "$UPSTREAM_NAME")"
    if [[ "$EXISTING_URL" != "$UPSTREAM_URL" ]]; then
        echo "Remote '$UPSTREAM_NAME' already exists with URL: $EXISTING_URL" >&2
        echo "Expected: $UPSTREAM_URL" >&2
        echo "Aborting so we don't overwrite your remote. Fix manually or remove the remote and re-run." >&2
        exit 1
    fi
else
    git remote add "$UPSTREAM_NAME" "$UPSTREAM_URL"
fi

# Shallow fetch of just the requested branch.
echo "Fetching $UPSTREAM_NAME $REF ..." >&2
git fetch --depth=1 "$UPSTREAM_NAME" "$REF" >/dev/null

# Exclusions: workshop side effects, not migration changes.
EXCLUDES=(
    ':(exclude)logs/**'
    ':(exclude)pids/**'
    ':(exclude)**/target/**'
    ':(exclude).idea/**'
    ':(exclude).vscode/**'
)

DIFF_ARGS=("$UPSTREAM_NAME/$REF" "--" )
if [[ -n "$PATH_FILTER" ]]; then
    DIFF_ARGS+=("$PATH_FILTER")
fi
DIFF_ARGS+=("${EXCLUDES[@]}")

echo
echo "=== diff --stat HEAD vs $UPSTREAM_NAME/$REF ${PATH_FILTER:+(filter: $PATH_FILTER)} ==="
git --no-pager diff --stat "${DIFF_ARGS[@]}"

echo
echo "=== diff HEAD vs $UPSTREAM_NAME/$REF ${PATH_FILTER:+(filter: $PATH_FILTER)} ==="
git --no-pager diff "${DIFF_ARGS[@]}"
