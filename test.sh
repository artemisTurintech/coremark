#!/bin/bash
set -e
cd "$(dirname "$0")"

if [[ -n "$WINDIR" ]]; then
    # On Windows the repo files and coremark.md5 have CRLF line endings.
    # Strip \r from filenames in the .md5 index and from each source file
    # before hashing, so the check matches the Linux-computed reference hashes.
    failed=0
    while IFS= read -r line; do
        line="${line%$'\r'}"                          # strip trailing \r
        [[ -z "$line" ]] && continue
        hash="${line%% *}"
        file="${line##*  }"
        computed=$(tr -d '\r' < "$file" | md5sum | cut -d' ' -f1)
        if [[ "$computed" == "$hash" ]]; then
            echo "$file: OK"
        else
            echo "$file: FAILED (expected $hash, got $computed)"
            failed=1
        fi
    done < coremark.md5
    [[ $failed -eq 0 ]] || exit 1
else
    make check PORT_DIR=linux
fi
