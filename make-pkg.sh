PKG_FILENAME="BushelScript.pkg"
PKG_IDENTIFIER="com.justcheesy.BushelScript-Installer"
PKG_VERSION="$(git describe --tags)"

# The temporary installed products dir.
# Will be created automatically.
# Will be deleted automatically after the pkg is made unless `noclean` is specified as the first script argument.
INSTALL_DIR="$(pwd)/install"

# Build everything into the installation directory.
xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$INSTALL_DIR" # Includes all language modules.
xcodebuild install -workspace Bushel.xcworkspace -scheme bushelscript DSTROOT="$INSTALL_DIR"
if [ $? -ne 0 ]
then
	echo 'xcodebuild install failed; not creating a pkg.'
	exit $?
fi

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
	rm -r "$INSTALL_DIR"
fi