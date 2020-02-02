#!/bin/bash
set -eo pipefail

# Set up LLVM in case that hasn't been done yet.
./set-up-llvm.sh

PKG_FILENAME="BushelScript.pkg"
PKG_IDENTIFIER="com.justcheesy.BushelScript-Installer"
PKG_VERSION="$(git describe --tags)"

# The temporary installed products dir.
# Will be created automatically.
# Will be deleted automatically after the pkg is made unless `noclean` is specified as the first script argument.
INSTALL_DIR="${INSTALL_DIR:-$(pwd)/install}"
echo "Building to ${INSTALL_DIR}"

# Build everything into the installation directory.
echo 'Installing.'
function install {
	xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$INSTALL_DIR" # Includes all language modules.
	if [ $? -ne 0 ]
	then
		echo 'xcodebuild install failed; not creating a pkg.'
		exit $?
	fi
}
if hash xcpretty 2>/dev/null
then
	echo 'Using xcpretty'
	install | xcpretty
else
	echo 'No xcpretty found (showing vanilla xcodebuild output)'
	install
fi

echo "Temporary measure: copying LLVM's libc++.1.dylib to install dir."
LLVM_LIB_DIR="$(brew --prefix llvm)/lib"
mkdir -p "$INSTALL_DIR/$LLVM_LIB_DIR"
LLVM_LIBCPP="$LLVM_LIB_DIR/libc++.1.dylib"
cp "$LLVM_LIBCPP" "$INSTALL_DIR/$LLVM_LIBCPP"

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
	echo "Removing build directory $INSTALL_DIR (specify \`noclean\` to disable.)"
	rm -r "$INSTALL_DIR"
fi
