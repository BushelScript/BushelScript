#!/bin/bash
set -eo pipefail

# Run tests.
echo 'Testing.'
function test {
	xcodebuild test -workspace Bushel.xcworkspace -scheme BushelScript\ Editor
}
if hash xcpretty 2>/dev/null
then
	echo 'Using xcpretty'
	test | xcpretty
else
	echo 'No xcpretty found (showing vanilla xcodebuild output)'
	test
fi
