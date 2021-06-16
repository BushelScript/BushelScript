#!/bin/bash
set -eo pipefail

hash xcpretty 2>/dev/null || function xcpretty { cat ; }
hash realpath 2>/dev/null || function realpath { python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$@" ; }

install_dir="$(realpath ${INSTALL_DIR:-install})"

echo "Installing to ${install_dir}…"
xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$install_dir" MARKETING_VERSION="$VERSION" | xcpretty
