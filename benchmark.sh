#!/bin/bash
set -e
cd "$(dirname "$0")"

# On Windows (Git Bash / MSYS), locate scoop's make and gcc by full path
if [[ -n "$WINDIR" ]]; then
    SCOOP="$(cygpath -u "$USERPROFILE")/scoop"
    MAKE="$SCOOP/shims/make.exe"
    GCC="$SCOOP/apps/gcc/current/bin/gcc.exe"
    "$MAKE" PORT_DIR=posix NO_LIBRT=1 CC="$GCC"
else
    make PORT_DIR=linux
fi
