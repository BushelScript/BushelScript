// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import XCTest
import Bushel
import BushelRT
@testable import BushelScript_Editor

private var bundle = Bundle(for: StandardLibraryTests.self)

class StandardLibraryTests: XCTestCase {
    
    override class func setUp() {
        LanguageModule.appBundle = Bundle(for: AppDelegate.self)
    }
    
    private func runTest(_ libraryName: String) {
        let testURL = bundle.url(forResource: "\(libraryName)Tests", withExtension: "bushel", subdirectory: "Tests")!
        XCTAssertNoThrow(try BushelRT.Runtime().run(Bushel.parse(from: testURL)))
    }
    
    func testList() { runTest("List") }
    
}
