// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Foundation

private let CFBundleShortVersionString = "CFBundleShortVersionString"

func printVersion() {
    let version = Bundle.main.object(forInfoDictionaryKey: CFBundleShortVersionString)!
    let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String)!
    print("bushelscript v\(version) (build \(build))")
}
