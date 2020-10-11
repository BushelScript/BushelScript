# BushelScript

## Automate macOS to new heights

![BushelScript Editor demo](Images/editor-demo.gif)

BushelScript is a next-generation open-source alternative to AppleScript; check out the [BushelScript website](https://bushelscript.github.io/) for more info.

## How do I…?

Check out the [help site](https://bushelscript.github.io/help/) for guides, reference material, and a community Discord server where you can ask questions.

## Disclaimer

1. This software is under active development and could change at any time and for any reason.
2. This software is not reliable in any way due to its unfinished and prototypal nature.
3. This software must not be used where reliability is at all required, as it is expected to malfunction.
4. The authors of this software DISCLAIM ALL WARRANTIES and SHALL NOT BE HELD LIABLE for any use or misuse of this software.

tl;dr please don't trust this software. It will crash inexplicably, report that 1 = 2, and eat the last slice of your pizza.

## Install BushelScript

See [releases on GitHub](https://github.com/BushelScript/BushelScript/releases). The latest version is at the top of the page.

## Build BushelScript from source

Building from source is always an option, and is pretty straightforward if you have Xcode installed and know your way around the command line.

To build BushelScript and create an installer package:

1. Clone this repository to your local machine. (`git clone https://github.com/BushelScript/BushelScript.git` in a Terminal prompt, or download the zip file from the web interface).
2. Make sure [Xcode](https://developer.apple.com/xcode) is installed.
3. In the directory that `git clone` created: `./make-pkg.sh`

Now you can `open BushelScript.pkg` (or double-click it) to run the installer.

If you're having trouble, please open an issue detailing the problem.

## Component listing

A BushelScript installation has the following components:

* Core frameworks, at `/Library/BushelScript/Core/*.framework`:
  - `SwiftAutomation.framework`
  - `Bushel.framework`
  - `BushelLanguage.framework`
  - `BushelRT.framework`
* Language service, `/Library/BushelScript/Core/BushelLanguageServiceConnectionCreation.framework`:
  - `BushelLanguageServiceConnectionCreation.framework`
    - `BushelLanguageService.xpc`
* Language modules, at `/Library/BushelScript/Languages/*.bundle`:
  - `bushelscript_en.bundle`
* BushelScript Editor application, at `/Applications/BushelScript Editor.app`
* `bushelscript` command-line tool, at `/usr/local/bin/bushelscript`

## Uninstall BushelScript

To uninstall BushelScript, remove the following files and directories:

* `/Library/BushelScript`
* `/Applications/BushelScript Editor.app`
* `/usr/local/bin/bushelscript`
