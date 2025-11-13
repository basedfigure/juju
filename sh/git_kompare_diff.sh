#!/usr/bin/env bash
#   Compare multiple files in a Git repo against their HEAD versions in a single
# Kompare window, ignoring .git directory.

set -eu

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 file1 [file2 ...]"
    exit 1
fi

files=()


for f in "$@"; do
    if [[ -d "$f" ]]; then
        while IFS= read -r file; do
            [[ "$file" == */.git/* ]] && continue
            files+=("$file")
        done < <(find "$f" -type f -not -path '*/.git/*')
    elif [[ -f "$f" ]]; then
        [[ "$f" == */.git/* ]] && continue
        files+=("$f")
    else
        echo "File not located: $f"
    fi
done

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No valid files found."
    exit 1
fi


repo_root=""
for file in "${files[@]}"; do
    dir="$(dirname "$file")"
    while [[ "$dir" != "/" ]]; do
        if git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1; then
            repo_root=$(git -C "$dir" rev-parse --show-toplevel)
            break 2
        fi
        dir="$(dirname "$dir")"
    done
done

if [[ -z "$repo_root" ]]; then
    echo "Not in a Git repo."
    exit 1
fi


tmpdir=$(mktemp -d /tmp/githead-XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

valid_files=()
for file in "${files[@]}"; do
    rel=$(realpath --relative-to="$repo_root" "$file")
    target="$tmpdir/$rel"
    mkdir -p "$(dirname "$target")"
    if git -C "$repo_root" show "HEAD:$rel" >"$target" 2>/dev/null; then
        valid_files+=("$rel")
    else
        echo "File $file not in HEAD (untracked?)"
    fi
done

if [[ ${#valid_files[@]} -eq 0 ]]; then
    echo "No files available in HEAD to compare."
    exit 1
fi


compare_dir="$tmpdir/compare"
mkdir -p "$compare_dir"

for rel in "${valid_files[@]}"; do
    mkdir -p "$compare_dir/$(dirname "$rel")"
    cp "$tmpdir/$rel" "$compare_dir/$rel"
done


work_dir="$tmpdir/work"
mkdir -p "$work_dir"

for rel in "${valid_files[@]}"; do
    mkdir -p "$work_dir/$(dirname "$rel")"
    cp "$repo_root/$rel" "$work_dir/$rel"
done


kompare "$compare_dir" "$work_dir" 2> >(grep -v "kf.kio" >&2)
