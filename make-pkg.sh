#!/bin/bash
set -eo pipefail

hash xcpretty 2>/dev/null || function xcpretty { cat; }

function get_project_version {
	xcodebuild -showBuildSettings -workspace Bushel.xcworkspace -scheme BushelScript\ Editor | grep MARKETING_VERSION | head -1 | tr -d '[:alpha:][:space:]_='
}

PKG_FILENAME="BushelScript.pkg"
PKG_IDENTIFIER="com.justcheesy.BushelScript-Installer"
PKG_VERSION="${RELEASE_VERSION:-$(get_project_version)+git.$(git rev-parse --short HEAD)}"

# The temporary installed products dir.
# Will be created automatically.
# Will be deleted automatically after the pkg is made unless `noclean` is specified as the first script argument.
INSTALL_DIR="${INSTALL_DIR:-$(pwd)/install}"
echo "Building to ${INSTALL_DIR}"

# Build everything into the installation directory.
echo 'Installing.'
# Includes all language modules.
xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$INSTALL_DIR" MARKETING_VERSION="$PKG_VERSION" | xcpretty
if [ $? -ne 0 ]
then
	echo 'xcodebuild install failed; not creating a pkg.'
	exit $?
fi

echo 'Cloning applescript-stdlib into install dir.'
APPLESCRIPT_STDLIB_INSTALL_DIR="${INSTALL_DIR}/Library/BushelScript/Libraries"
APPLESCRIPT_STDLIB_CLONE_DIR="${INSTALL_DIR}/applescript-stdlib"
rm -rf "$APPLESCRIPT_STDLIB_CLONE_DIR"
git clone --depth=1 'https://github.com/BushelScript/applescript-stdlib.git' "$APPLESCRIPT_STDLIB_CLONE_DIR"
mkdir -p "$APPLESCRIPT_STDLIB_INSTALL_DIR"
cp -r "$APPLESCRIPT_STDLIB_CLONE_DIR"/*.scptd "$APPLESCRIPT_STDLIB_INSTALL_DIR"
rm -rf "$APPLESCRIPT_STDLIB_CLONE_DIR"

# Make the installer package.
pkgbuild --root "$INSTALL_DIR" --identifier "$PKG_IDENTIFIER" --version "$PKG_VERSION" "$PKG_FILENAME"
if [ $? -ne 0 ]
then
	echo "pkgbuild failed; not removing ${INSTALL_DIR}."
	exit $?
fi

# Delete the install directory unless `noclean` is specified.
if [ "$1" != "noclean" ]
then
	echo "Cleaning (specify \`noclean\` to disable.)"
	xcodebuild clean -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$INSTALL_DIR" | xcpretty
fi
