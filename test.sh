#!/bin/bash
set -eo pipefail

hash xcpretty 2>/dev/null || function xcpretty { cat; }

# Run tests.
echo 'Testing.'
xcodebuild test -workspace Bushel.xcworkspace -scheme BushelScript\ Editor | xcpretty
