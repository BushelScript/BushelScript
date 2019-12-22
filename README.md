# BushelScript

Next-generation open-source AppleScript.

## About

**BushelScript** is best described as a next-generation open-source alternative to AppleScript.

As opposed to its big brother, BushelScript is open-source and community-driven, meaning it can undergo necessary changes and gain useful features rather than remain stagnant as a side project on life support.

The real tragedy of AppleScript is not its becoming obsolete or irrelevant; tons of Apple-supported macOS apps still have healthy scripting interfaces. No, the tragedy is that the language through which such functionality is presented, with all its quirks and weak points and even utter failures, is extremely unlikely to receive any badly needed improvements in the future, if any changes at all. It is stuck in maintenance (read: bugfix and security hole-filling) mode and will be for years to come if we, the users, don't replace it with something better whose fate we can control.

It's been my pet project for over three years now to try to create a less-frustrating yet equally useful alternative to the confusing and arcane nightmare that is AppleScript. BushelScript aims to do everything that made AppleScript useful, and hopefully do it better.

That said, here's a pitch I wrote near the beginning of the project in its current form:

### Manifesto

BushelScript is a next-generation open-source reimplementation of AppleScript that's more usable, predictable and extensible.

* **Next-generation:** BushelScript’s design is more modern and robust than AppleScript’s: written from the ground up for an operating system with memory segmentation and multitasking!
* **Open-source:** BushelScript’s source code is very intentionally open to the public: through the muddy waters that lurk in the dark corners of AppleScript none shall trudge again
* **Reimplementation:** BushelScript is meant to eventually be a complete AppleScript replacement. 1\. Convert scripts 2\. AWW YEH 3\. Profit (from the project's open-source nature, of course)
* **AppleScript:** BushelScript reimplements **AppleScript**: you know, the language that lets you manipulate your graphical applications in exchange for your sanity, soul, and all the good variable names, whilst barfing up four different function definition syntaxes? Yeah, that one
* **More usable:** BushelScript sports a sweet host of built-in libraries: no more outsourcing your string chopping to avoid fun dances like the (characters 1 thru (length of the\_string - (offset of " " in (reverse of characters of the\_string as string))) of the\_string) as string/and/dammit/I/forgot/to/reset/my/text/item/delimiters
* **More predictable:** BushelScript eschews the unexpected, providing avoidance mechanisms for terminology conflicts, “can’t continue”s, HFS path strings, and other summer hailstorms
* **More extensible:** BushelScript nearly bursts at the seams with extension opportunities: but it won't, of course, because it doesn’t need any patchwork to hold it all together. Scripting additions and FBAs, begone!

Some more technical specifics; BushelScript:

* Intends to replace AppleScript, so that you never need to write another line of it again
* Has AppleScript-like syntax, so as to maintain average Joe usability
* If you cringed at that last point, I promise it’s improved this time, but even then BushelScript gives you options ;)
* Does **not** reimplement the entire AppleScript language just to be compatible with existing scripts
    * BushelScript *was* initially to be a simple open source reimplementation of AppleScript, but
    * AppleScript has warts-o-plenty in its core design, hurting its reputation amongst professional programmers and amateur app scripters alike
    * Also, in general, AppleScript is pretty poorly understood, and while an open source version would help with that, why not just *make it easier?*
* Has or intends in the future to have the following interfaces:
    * Dynamic Swift library interface to compile, run, etc. scripts (analog: OSAKit)
    * Lower-level interface to perform parse tree-level program display formatting and transformations (analog: AppleScript script display formatting, Clang fix-its)
    * A Script Editor-esque application with three script display modes:
        * A text mode that displays styled formatted script text (analog: AppleScript formatted script text)
        * A graphical mode that uses buttons and menus to that are easier to get started with (analog: Scratch language; but not drag’n’drop)
        * A hybrid of the two, where the text is editable but there are still coloured boxes, drop-down menus, and assistive buttons that are a little more out of the way, to allow for quickly typing scripts while still having the convenience of the blocks mode
    * An Automator action to run BushelScript scripts (analog: Run AppleScript action)
    * A command-line script running tool (analog: `​osascript`​)
* Relies on a language module system, similar in spirit to early AppleScript’s “dialects” but less arcane
* Has two primary language modules:
    * BushelScript is the AppleScript lookalike language for everyone
    * AS++ is specifically targeted towards programmers who want to get scripting stuff done quicker and with a syntax that's more familiar and symbol-heavy
    * English is of course the dominant version of these two, but they could theoretically be ported to a wider range of natural language bases—e.g., English names are “BushelScript (English)”, `​bushelscript_en`​, and “AS++ (English)”, `​aspp_en`​, while French names would be “BushelScript (français)”, `​bushelscript_fr`​, and “AS++ (français)”, `​aspp_fr`​.

## Status

Currently, the language is in its early- to mid-growth stages. New features are being added very often, and some will likely be changed or removed with time.

The graphical BushelScript Editor application is also functional but very basic at the moment. I hope to drastically improve the interface once the API and language are more mature and finalized.

### Installation

There's no automated installer yet. For now, you can build the project yourself, which should be pretty straightforward.

To build the core frameworks, language service, English module and graphical Editor from source, do the following:

1. Clone the [GitHub repository](https://github.com/BushelScript/BushelScript) to your local machine. (`git clone https://github.com/BushelScript/BushelScript` in a Terminal prompt, or download the zip file from the web interface).
2. Make sure [Homebrew](https://brew.sh) and [Xcode](https://developer.apple.com/xcode) are installed. 
3. `brew install llvm`
4. `xcodebuild install -workspace Bushel.xcworkspace -scheme BushelScript\ Editor DSTROOT=/`

Language modules are installed to `/Library/BushelScript/Languages` and BushelScript Editor is placed in `/Applications`. Launch the app to begin writing BushelScript programs.

If this doesn't work or you believe I've missed a step, please open an issue.

## Why “BushelScript”?

Since the language is basically just an improved, next-gen AppleScript, I wanted to pun off of that name. For the first few months of the project's life, it was called “AppleScript+”. However, I eventually realized that this could cause trademark issues. The code needed to be scrapped and started from scratch anyway, so from that point on I named it “BushelScript”, after the fruit basket measure commonly used to sell apples.

## Important usage notes and disclaimer

1. This project is still under heavy and active development. Anything could change at any time and for any reason.
2. This software is not reliable in any way due to its unfinished and semi-prototype-y nature.
3. You must not rely on this software to do business, control real-world systems, or in any other applications where reliability is at all required.
4. I, Ian A. Gregory, WILL NOT BE HELD LIABLE for any damages resulting from the failure to read, understand and apply this disclaimer.

I know that this is legally weak, IANAL, etc. But it shouldn't need to be legally strong. Please don't trust this software until things stabilize. Okay?
