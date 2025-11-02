#!/usr/bin/env bash
# Compare arbitrary files against their own Git HEAD in Kompare.
# (Shows diff between working copy and last commit.)

set -eu

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 file1 [file2 ...]"
  exit 1
fi

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "File not located: $f"
    continue
  fi

  repo_root=$(
    git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || true
  )
  if [[ -z "$repo_root" ]]; then
    echo "Not in a Git repo: $f"
    continue
  fi

  rel=$(realpath --relative-to="$repo_root" "$f")
  tmp=$(mktemp /tmp/gitold-XXXXXX)

  if ! git -C "$repo_root" show "HEAD:$rel" >"$tmp" 2>/dev/null; then
    echo "File $f not in HEAD (untracked?)"
    rm -f "$tmp"
    continue
  fi

  echo
  echo "──────────────────────────────────────────────"
  echo " Kompare opened: $rel"
  echo " -> Showing: HEAD (left) vs working copy (right)"
  kompare "$tmp" "$f" 2> >(grep -v "kf.kio" >&2)
  echo "──────────────────────────────────────────────"

  rm -f "$tmp"
done
