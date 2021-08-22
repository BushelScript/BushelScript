# Components of a BushelScript installation

BushelScript components are installed in `BushelScript` folders in any standard `Library` folder, i.e., `/Users/you/Library`, `/Library`, and `/Network/Library`. As of v0.4.0, a BushelScript installation is a self-contained `.app` package. The `Resources` folder of this package acts like a `Library/BushelScript` folder to a certain degree.

You can currently add the following types of components to `Library/BushelScript` folders: 
  - Language modules, in `Languages/`
  - Libraries (BushelScript or AppleScript), in `Libraries/`

The app package contains the following core components:
  - Core frameworks: `SharedFrameworks/`
    - Common structure (including AST) definitions, language module API: `Bushel.framework`
    - Runtime: `BushelRT.framework`
  - Language modules: `Languages/`
    - `bushelscript_en.bundle`
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
  - Command line tool (script runner and REPL): `bushelscript`
    - This is symlinked into the appropriate location when the user installs it in Preferences

[AppleScript-stdlib]: https://github.com/BushelScript/applescript-stdlib
