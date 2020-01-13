# BushelScript

**BushelScript** is a next-generation open-source alternative to AppleScript.

See the [BushelScript website](https://bushelscript.github.io/) for more info: [About BushelScript](https://bushelscript.github.io/about/)

## Build BushelScript from source

There's no automated installer yet. For now, you can build the project yourself, which is pretty straightforward if you have Xcode installed and know your way around the command line.

To build BushelScript on your local machine and create an installer package:

1. Clone this repository to your local machine. (`git clone https://github.com/BushelScript/BushelScript.git` in a Terminal prompt, or download the zip file from the web interface).
2. Make sure [Homebrew](https://brew.sh) and [Xcode](https://developer.apple.com/xcode) are installed. 
3. Install LLVM as a system package: `brew install llvm`
4. In the directory that `git clone` created: `./make-pkg.sh`

Now you can `open BushelScript.pkg` (or double-click it) to run the installer.

Installed components include: core frameworks (`Bushel.framework`, `BushelLanguage.framework` and `BushelRT.framework`); language service (`BushelLanguageService.xpc`, `BushelLanguageServiceConnectionCreation.framework`); English language module (`bushelscript_en.framework`); BushelScript Editor (`BushelScript Editor.app`); and the `bushelscript` command-line tool. Components are installed as follows:

* Core frameworks: `/Library/Frameworks/*.framework`
* Language service: embedded in `BushelScript Editor.app`
* Language modules: `/Library/BushelScript/Languages/*.framework`
* BushelScript Editor : `/Applications/BushelScript Editor.app`
* `bushelscript` command-line tool: `/usr/local/bin/bushelscript`

If you want to uninstall BushelScript, remove these components.

If these build or uninstall instructions don't work, or you're otherwise having trouble, please open an issue.

## Important usage notes and disclaimer

1. This project is still under heavy and active development. Anything could change at any time and for any reason.
2. This software is not reliable in any way due to its unfinished and semi-prototype-y nature.
3. You must not rely on this software to do business, control real-world systems, or in any other applications where reliability is at all required.
4. I, Ian A. Gregory, WILL NOT BE HELD LIABLE for any damages resulting from the failure to read, understand and apply this disclaimer.

I know that this is legally weak, IANAL, etc. But it shouldn't need to be legally strong. Please don't trust this software until things stabilize. Okay?
