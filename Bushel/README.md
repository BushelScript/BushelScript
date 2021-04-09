#  Bushel

This framework includes basic language-agnostic data structures and algorithms, defines the API for language modules, and provides consumer API for implementing concrete languages:

- Language module connection algorithms and API definitions (`Language Modules`)
    - Read this code if you want to write a language module, in the absence of official documentation (which should come eventually).
- Error description structures (`ParseError.swift`)
- Source fix description structures and application algorithms (`SourceFix.swift`)
- Structure for parsed programs and associated artifacts (`Program.swift`)
- Algorithms to inspect and pretty print source code (`AST-dervied Output`)
- A language-agnostic, enum-based abstract syntax tree (`AST`)
- Terminology structures, storage and organization methods, and declarative creation facilities (`Terminology`)
- Utility code, also available to language modules (`Utility`)
