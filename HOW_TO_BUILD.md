# Build BushelScript from source

Building from source is pretty straightforward, especially if you're familiar with the command line.

## Prerequisites

Complete these steps before proceeding:

1. Make sure [Xcode](https://developer.apple.com/xcode) 12 or later is installed.
2. Clone this repository to your local machine. (e.g., run `git clone https://github.com/BushelScript/BushelScript` in a Terminal prompt, or click the "Open with Xcode" button in the GitHub web interface.)

## Development

To set up a BushelScript development environment:

1. Open the `xcworkspace` package in Xcode.
2. Select a scheme to build. Note that the BushelScript Editor scheme will build everything.
3. Hack away.

## Release

To create a release build:

1. In the directory to which you downloaded the code, run `./build.sh`.
2. If the build succeeds, it will have created `install/Applications/BushelScript Editor.app` in the current directory. You can run or distribute this as you wish.

## Something broke

Please open an issue detailing the problem.
