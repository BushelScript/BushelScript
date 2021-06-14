//
//  AppleEventFormatter.swift
//  SwiftAutomation
//
//  Format an AppleEvent descriptor as Swift source code. Enables user tools to translate application commands from AppleScript to Swift syntax simply by installing a custom SendProc into an AS component instance to intercept outgoing AEs, pass them to formatAppleEvent(), and print the result.
//
//

// TO DO: Application object should appear as `APPLICATION()`, not `APPLICATION(name:"/PATH/TO/APP")`, for display in SwiftAutoEdit's command translator -- probably simplest to have a boolean arg to formatAppleEvent that dictates this (since the full version is still useful for debugging work)... might be worth making this an `app/application/fullApplication` enum to cover PREFIXApp case as well

// TO DO: Symbols aren't displaying correctly within arrays/dictionaries/specifiers (currently appear as `Symbol.NAME` instead of `PREFIX.NAME`), e.g. `TextEdit(name: "/Applications/TextEdit.app").make(new: TED.document, withProperties: [Symbol.text: "foo"])`; `tell app "textedit" to document (text)` -> `TextEdit(name: "/Applications/TextEdit.app").documents[Symbol.text].get()` -- note that a custom Symbol subclass won't work as `description` can't be parameterized with prefix name to use; one option might be a Symbol subclass whose init takes the prefix as param when it's unpacked (that probably will work); that said, why isn't Formatter.formatSymbol() doing the job in the first place? (check it has correct prefix) -- it's formatValue() -- when formatting collections, it calls itself and then renders self-formatting objects as-is

import Foundation
import AppKit

public enum TerminologyType {
    case aete // old and nasty, but reliable; can't be obtained from apps with broken `ascr/gdte` event handlers (e.g. Finder)
    case sdef // reliable for Cocoa apps only; may be corrupted when auto-generated for aete-only Carbon apps due to bugs in macOS's AETE-to-SDEF converter and/or limitations in XML/SDEF format (e.g. SDEF format represents OSTypes as four-character strings, but some OSTypes can't be represented as text due to 'unprintable characters', and SDEF format doesn't provide a way to represent those as [e.g.] hex numbers so converter discards them instead)
    case none // use default terminology + raw four-char codes only
}

public func formatAppleEvent(descriptor event: NSAppleEventDescriptor, useTerminology: TerminologyType = .sdef) -> String { // TO DO: return command/reply/error enum, giving caller more choice on how to display
    //  Format an outgoing or reply AppleEvent (if the latter, only the return value/error description is displayed).
    //  Caution: if sending events to self, caller MUST use TerminologyType.SDEF or call formatAppleEvent on a background thread, otherwise formatAppleEvent will deadlock the main loop when it tries to fetch host app's AETE via ascr/gdte event.
    if event.descriptorType != _typeAppleEvent { // sanity check
        return "Can't format Apple event: wrong type: \(formatFourCharCodeString(event.descriptorType))."
    }
    if event.attributeDescriptor(forKeyword: _keyEventClassAttr)!.typeCodeValue == _kCoreEventClass
            && event.attributeDescriptor(forKeyword: _keyEventIDAttr)!.typeCodeValue == _kAEAnswer { // it's a reply event, so format error/return value only
        let errn = event.paramDescriptor(forKeyword: _keyErrorNumber)?.int32Value ?? 0
        if errn != 0 { // format error message
            let errs = event.paramDescriptor(forKeyword: _keyErrorString)?.stringValue
            return AutomationError(code: Int(errn), message: errs).errorDescription! // TO DO: use CommandError? (need to check it's happy with only replyEvent arg)
        } else if let reply = event.paramDescriptor(forKeyword: _keyDirectObject) { // format return value
            return formatSAObject((try? AppData().unpackAsAny(reply)) ?? reply)
        } else {
            return MissingValue.description
        }
    } else { // fully format outgoing event
        return formatCommand(CommandDescription(event: event, appData: AppData()), applicationObject: AppData().application)
    }
}

/******************************************************************************/
// unpack AppleEvent descriptor's contents into struct, to be consumed by SpecifierFormatter.formatCommand()

public struct CommandDescription {
    
    // note: even when terminology data is available, there's still no guarantee that a command won't have to use raw codes instead (typically due to dodgy terminology; while AS allows mixing of keyword and raw chevron syntax in the same command, it's such a rare defect it's best to stick solely to one or the other)
    public enum Signature {
        case named(name: String, directParameter: Any, keywordParameters: [(String, Any)], requestedType: Symbol?)
        case codes(eventClass: OSType, eventID: OSType, parameters: [OSType:Any])
    }
    
    // name and parameters
    public let signature: Signature // either keywords or four-char codes
    
    // attributes (note that waitReply and withTimeout values are unreliable when extracted from an existing AppleEvent)
    public private(set) var subject: Any? = nil // TO DO: subject or parentSpecifier? (and what, if any, difference does it make?)
    public private(set) var waitReply: Bool = true // note that existing AppleEvent descriptors contain keyReplyRequestedAttr, which could be either SendOptions.waitForReply or .queueReply
    // TO DO: also include sendOptions for completeness
    public private(set) var withTimeout: TimeInterval = defaultTimeout
    public private(set) var considering: ConsideringOptions = [.case]
    
    // called by sendAppleEvent with a failed command's details
    public init(name: String?, eventClass: OSType, eventID: OSType, parentSpecifier: Any?,
                directParameter: Any, keywordParameters: [KeywordParameter],
                requestedType: Symbol?, waitReply: Bool, withTimeout: TimeInterval?, considering: ConsideringOptions?) {
        if let commandName = name {
            self.signature = .named(name: commandName, directParameter: directParameter,
                                    keywordParameters: keywordParameters.map { ($0!, $2) }, requestedType: requestedType)
        } else {
            var parameters = [OSType:Any]()
            if parameterExists(directParameter) { parameters[_keyDirectObject] = directParameter }
            for (_, code, value) in keywordParameters where parameterExists(value) { parameters[code] = value }
            if let symbol = requestedType { parameters[_keyAERequestedType] = symbol }
            self.signature = .codes(eventClass: eventClass, eventID: eventID, parameters: parameters)
        }
        self.waitReply = waitReply
        self.subject = parentSpecifier
        if withTimeout != nil { self.withTimeout = withTimeout! }
        if considering != nil { self.considering = considering! }
    }
    
    // called by [e.g.] SwiftAutoEdit.app with an intercepted AppleEvent descriptor
    public init(event: NSAppleEventDescriptor, appData: AppData) {
        // unpack the event's parameters
        var rawParameters = [OSType:Any]()
        for i in 1...event.numberOfItems {
            let desc = event.atIndex(i)!
            rawParameters[event.keywordForDescriptor(at:i)] = (try? appData.unpackAsAny(desc)) ?? desc
        }
        //
        let eventClass = event.attributeDescriptor(forKeyword: _keyEventClassAttr)!.typeCodeValue
        let eventID = event.attributeDescriptor(forKeyword: _keyEventIDAttr)!.typeCodeValue
        self.signature = .codes(eventClass: eventClass, eventID: eventID, parameters: rawParameters)
        // unpack subject attribute, if given
        if let desc = event.attributeDescriptor(forKeyword: _keySubjectAttr) {
            if desc.descriptorType != _typeNull { // typeNull = root application object
                self.subject = (try? appData.unpackAsAny(desc)) ?? desc // TO DO: double-check formatter knows how to display descriptor (or any other non-specifier) as customRoot
            }
        }
        // unpack reply requested and timeout attributes (note: these attributes are unreliable since their values are passed via AESendMessage() rather than packed directly into the AppleEvent)
        if let desc = event.attributeDescriptor(forKeyword: _keyReplyRequestedAttr) { // TO DO: attr is unreliable
            // keyReplyRequestedAttr appears to be boolean value encoded as Int32 (1=wait or queue reply; 0=no reply)
            if desc.int32Value == 0 { self.waitReply = false }
        }
        if let timeout = event.attributeDescriptor(forKeyword: _keyTimeoutAttr) { // TO DO: attr is unreliable
            let timeoutInTicks = timeout.int32Value
            if timeoutInTicks == -2 { // NoTimeout // TO DO: ditto
                self.withTimeout = -2
            } else if timeoutInTicks > 0 {
                self.withTimeout = Double(timeoutInTicks) / 60.0
            }
        }
        // considering/ignoring attributes
        if let considersAndIgnoresDesc = event.attributeDescriptor(forKeyword: _enumConsidsAndIgnores) {
            var considersAndIgnores: UInt32 = 0
            (considersAndIgnoresDesc.data as NSData).getBytes(&considersAndIgnores, length: MemoryLayout<UInt32>.size)
            if considersAndIgnores != defaultConsidersIgnoresMask {
                for (option, _, considersFlag, ignoresFlag) in considerationsTable {
                    if option == .case {
                        if considersAndIgnores & ignoresFlag > 0 { self.considering.remove(option) }
                    } else {
                        if considersAndIgnores & considersFlag > 0 { self.considering.insert(option) }
                    }
                }
            }
        }
    }
}
