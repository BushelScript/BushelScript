//
//  HashbangTests.swift
//  BushelScript EditorTests
//
//  Created by Ian Gregory on 31-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import XCTest
@testable import BushelScript_Editor
import Defaults

class HashbangTests: XCTestCase {
    
    // We'd need variadic generics to properly express this in terms of `Defaults.Key<>`s
    private func withDefaults(_ newDefaults: [(String, Any?)], perform action: () throws -> Void) rethrows {
        var oldDefaults: [(String, Any?)] = []
        for (key, newValue) in newDefaults {
            oldDefaults.append((key, UserDefaults.standard.object(forKey: key)))
            UserDefaults.standard.set(newValue, forKey: key)
        }
        defer {
            for (key, oldValue) in oldDefaults {
                UserDefaults.standard.set(oldValue, forKey: key)
            }
        }
        try action()
    }
    
    private func withTemporaryDirectory(perform action: (URL) -> Void) {
        let tempDir = try! FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: URL(fileURLWithPath: NSHomeDirectory()), create: true)
        defer { try! FileManager.default.removeItem(at: tempDir) }
        action(tempDir)
    }
    
    private func saving(_ document: NSDocument, perform action: @escaping (URL, Error?) -> Void) {
        withTemporaryDirectory { tempDir in
            let saveLocation = tempDir.appendingPathComponent("saved.bushel")
            let expect = expectation(description: "Save completion handler called")
            document.save(to: saveLocation, ofType: "BushelScript script", for: .saveAsOperation, completionHandler: { error in
                action(saveLocation, error)
                expect.fulfill()
            })
            wait(for: [expect], timeout: 5)
        }
    }
    
    private func loadDocument(named name: String) -> Document {
        return try! NSDocumentController.shared.makeDocument(withContentsOf: Bundle(for: HashbangTests.self).url(forResource: name, withExtension: "bushel")!, ofType: "BushelScript script") as! Document
    }
    
    var documents: [Document] {
        return [
            loadDocument(named: "NoHashbang"),
            loadDocument(named: "CustomHashbang")
        ]
    }
    
    /// Tests the default hashbang-adding behaviour.
    func test_defaultHashbang_addedOrOverwrittenOnSave() {
        for document in documents {
            withDefaults([
                (Defaults.Keys.addHashbangOnSave.name, nil),
                (Defaults.Keys.addHashbangOnSaveProgram.name, nil),
                (Defaults.Keys.addHashbangOnSaveUseLanguageFlag.name, nil)
            ]) {
                saving(document) { saveLocation, error in
                    XCTAssertNil(error)
                    let contents = try! String(contentsOf: saveLocation)
                    XCTAssertEqual(
                        contents.prefix(while: { !$0.isNewline }),
                        "#!\(Defaults.Keys.addHashbangOnSaveProgram.defaultValue) -l bushelscript_en"
                    )
                }
            }
        }
    }
    
    /// Ensures custom hashbangs found in a file are preserved when changes
    /// are written back to it while "Add Hashbang on Save" is disabled.
    func test_customHashbang_roundTripsWhenNoneToBeAdded() {
        let document = loadDocument(named: "CustomHashbang")
        
        withDefaults([(Defaults.Keys.addHashbangOnSave.name, false)]) {
            saving(document) { saveLocation, error in
                XCTAssertNil(error)
                let contents = try! String(contentsOf: saveLocation)
                XCTAssertEqual(
                    contents.prefix(while: { !$0.isNewline }),
                    "#!/usr/bin/osascript"
                )
            }
        }
    }
    
    /// Ensures user-specified hashbangs are added (or a custom hashbang
    /// overwritten) when a document is saved. Uses the language flag.
    func test_customHashbang_addedOrOverwrittenOnSave_withLanguageFlag() {
        for document in documents {
            withDefaults([
                (Defaults.Keys.addHashbangOnSave.name, true),
                (Defaults.Keys.addHashbangOnSaveProgram.name, "/bin/bash"),
                (Defaults.Keys.addHashbangOnSaveUseLanguageFlag.name, true)
            ]) {
                saving(document) { saveLocation, error in
                    XCTAssertNil(error)
                    let contents = try! String(contentsOf: saveLocation)
                    XCTAssertEqual(
                        contents.prefix(while: { !$0.isNewline }),
                        "#!/bin/bash -l bushelscript_en"
                    )
                }
            }
        }
    }
    
    /// Ensures user-specified hashbangs are added (or a custom hashbang
    /// overwritten) when a document is saved. Does not use the language flag.
    func test_customHashbang_addedOnSave_withoutLanguageFlag() {
        for document in documents {
            withDefaults([
                (Defaults.Keys.addHashbangOnSave.name, true),
                (Defaults.Keys.addHashbangOnSaveProgram.name, "/bin/bash"),
                (Defaults.Keys.addHashbangOnSaveUseLanguageFlag.name, false)
            ]) {
                saving(document) { saveLocation, error in
                    XCTAssertNil(error)
                    let contents = try! String(contentsOf: saveLocation)
                    XCTAssertEqual(
                        contents.prefix(while: { !$0.isNewline }),
                        "#!/bin/bash"
                    )
                }
            }
        }
    }
    
}
