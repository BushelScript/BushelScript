# Components of a BushelScript installation

A standard BushelScript installation consists of the following components:

- Shared components: `/Library/BushelScript/`
  - Core frameworks: `Core/`
    - AppleEvent support: `SwiftAutomation.framework`
    - Common structure (including AST) definitions: `Bushel.framework`
    - Language module (parser and formatter) API: `BushelLanguage.framework`
    - Runtime: `BushelRT.framework`
    - XPC service consumer API: `BushelLanguageServiceConnectionCreation.framework/`:
      - XPC service: `XPCServices/BushelLanguageService.xpc`
  - Language modules: `Languages/`
    - `bushelscript_en.bundle`
    - …any other installed language modules…
  - Internal applications: `Applications/`
    - Background app responsible for GUI commands: `BushelGUIHost.app`
  - Libraries: `Libraries/`
    - [AppleScript "standard" libraries][AppleScript-stdlib]:
      - `Date.scptd`
      - `File.scptd`
      - `List.scptd`
      - `Number.scptd`
      - `Objects.scptd`
      - `Text.scptd`
      - `TypeSupport.scptd`
      - `Web.scptd`
    - …any other installed libraries…
- Applications: `/Applications/`
  - BushelScript Editor: `BushelScript Editor.app`
- Command-line programs: `/usr/local/bin/`
  - Script runner and REPL: `bushelscript`

[AppleScript-stdlib]: https://github.com/BushelScript/applescript-stdlib
