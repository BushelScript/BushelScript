#!/bin/bash
set -eo pipefail

hash xcpretty 2>/dev/null || function xcpretty { cat; }

function get_project_version {
	xcodebuild -showBuildSettings -workspace Bushel.xcworkspace -scheme BushelScript\ Editor | grep MARKETING_VERSION | head -1 | tr -d '[:alpha:][:space:]_='
}

# The temporary installed products dir.
# Will be created automatically.
# Will be deleted automatically after the pkg is made unless `noclean` is specified as the first script argument.
install_dir="${INSTALL_DIR:-$(pwd)/install}"
echo "Building to ${install_dir}…"

# Build everything into the installation directory.
echo 'Installing…'
# Includes all language modules.
xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT="$install_dir" MARKETING_VERSION="$VERSION" | xcpretty
if [ $? -ne 0 ]
then
	echo 'xcodebuild install failed.'
	exit $?
fi
