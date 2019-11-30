//
//  KeywordConverter.swift
//  SwiftAutomation
//
//  Convert AETE/SDEF-defined keywords from AppleScript syntax to a form suitable for use in a client language
//

import Foundation

public protocol KeywordConverter {
    
    var defaultTerminology: ApplicationTerminology { get }
    
    func convertSpecifierName(_ s: String) -> String
    func convertParameterName(_ s: String) -> String
    func identifierForAppName(_ appName: String) -> String
    func prefixForAppName(_ appName: String) -> String
    func escapeName(_ s: String) -> String // TO DO: make sure this is always applied correctly (might also be wise to document dos/don'ts for implementing it correctly)
    
}

public class NoOpKeywordConverter: KeywordConverter {
    
    public var defaultTerminology: ApplicationTerminology {
        return DefaultTerminology(keywordConverter: self)
    }
    
    public func convertSpecifierName(_ s: String) -> String {
        return s
    }
    public func convertParameterName(_ s: String) -> String {
        return s
    }
    public func identifierForAppName(_ appName: String) -> String {
        return appName
    }
    public func prefixForAppName(_ appName: String) -> String {
        return appName
    }
    public func escapeName(_ s: String) -> String {
        return s
    }
    
}
