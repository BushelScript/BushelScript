#!/bin/bash
set -euo pipefail

# Accessible from parent shell if this script is source'd.
PACKAGES_DIR="${PACKAGES_DIR:-$(pwd)/swift-packages}"
echo "Resolving package dependencies to ${PACKAGES_DIR}"

# Resolve Swift package dependencies.
xcodebuild -resolvePackageDependencies -workspace Bushel.xcworkspace -scheme BushelScript\ Editor -clonedSourcePackagesDirPath "$PACKAGES_DIR"
