#!/bin/bash
set -eo pipefail

PKGCONFIG_FILE=/usr/local/lib/pkgconfig/cllvm.pc
if [ -e "$PKGCONFIG_FILE" ]
then
	echo 'cllvm.pc already set up.'
else
	echo 'Creating cllvm.pc.'
	export PACKAGES_DIR="$(pwd)/swift-packages"
	./resolve-packages.sh
	PREVDIR="$(pwd)"
	
	cd "$PACKAGES_DIR/checkouts/LLVMSwift"
	PATH="$(brew --prefix llvm)/bin:$PATH" swift utils/make-pkgconfig.swift
	
	cd "$PREVDIR"
	rm -rf "$PACKAGES_DIR"
fi
