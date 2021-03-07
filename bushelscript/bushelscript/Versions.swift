// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Foundation

private let CFBundleShortVersionString = "CFBundleShortVersionString"

private let toolVersion = "0.3.0"
private let frameworks = ["Bushel", "BushelLanguage", "BushelRT", "SwiftAutomation"]
private let frameworkForMainVersion = "Bushel"

private func version(of framework: String) -> String? {
    let frameworkBundle = Bundle(identifier: "com.justcheesy.\(framework)")
    return frameworkBundle?.infoDictionary?[CFBundleShortVersionString].flatMap { version in
        version as? String
    }
}

// Returns exit status code.
func printVersion() -> Int32 {
    let frameworkVersions = [String : String](uniqueKeysWithValues: frameworks.compactMap { frameworkName in
        version(of: frameworkName).map { (frameworkName, $0) }
    })
    
    var exitStatusCode: Int32 = 0
    
    func versionDescription(for frameworkName: String) -> String {
        if let version = frameworkVersions[frameworkName] {
            return "Using \(frameworkName).framework version \(version)"
        } else {
            exitStatusCode = 4
            return "\(frameworkName).framework is missing!"
        }
    }
    
    print("""

BushelScript command-line interface version \(toolVersion)

\(frameworks.map(versionDescription).joined(separator: "\n"))

""")
    
    return exitStatusCode
}

// For the REPL intro.
func printShortVersion() {
    let versionDescription = version(of: frameworkForMainVersion).map {
        "BushelScript version \($0)"
    } ??
        "No BushelScript installation detected!"
    print("\(versionDescription) (tool version \(toolVersion))")
}
