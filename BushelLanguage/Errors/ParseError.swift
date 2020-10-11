import Bushel

/// Any parser error.
public protocol ParseErrorProtocol: Error, Located {
    
    /// The source location to which the error applies.
    var location: SourceLocation { get set }
    
    /// Any number of applicable automatic source fixes.
    var fixes: [SourceFix] { get }
    
}

/// A predefined parser error thrown by the reusable components of `SourceParser`,
/// or by a language module that implements similar functionality itself.
public struct ParseError: ParseErrorProtocol {
    
    /// The predefined error this `ParseError` represents.
    public let error: Error
    
    // ParseErrorProtocol
    public var location: SourceLocation
    public let fixes: [SourceFix]
    
    public init(_ error: Error, at location: SourceLocation, fixes: [SourceFix] = []) {
        self.error = error
        self.location = location
        self.fixes = fixes
    }
    
    public enum Error {
        
        case missing(SourceElement)
        case unmetResourceRequirement(ResourceRequirement)
        case invalidResourceType(validTypes: [TermName])
        case terminologyImportFailure(error: Swift.Error)
        case quotedResourceTerm
        case invalidString
        case invalidNumber
        case undefinedTerm
        case mismatchedPipe
        case invalidTermType
        case rawFormTermNotConstructible
        case wrongTermTypeForContext
        
        public enum SourceElement {
            
            case resourceName
            case endTagOrLineBreak(endTag: TermName)
            case expressionAfterKeyword(keyword: TermName)
            case lineBreakAfterSequencedExpression
            case expressionAfterBinaryOperator
            case expressionAfterPrefixOperator
            case expressionAfterPostfixOperator
            case groupedExpressionAfterBeginMarker(beginMarker: TermName)
            case groupedExpressionEndMarker(endMarker: TermName)
            case recordKeyBeforeKeyValueSeparatorOrEndMarkerAfter(keyValueSeparator: TermName, endMarker: TermName)
            case listItemSeparatorOrEndMarker(itemSeparator: TermName, endMarker: TermName)
            case recordKeyValueSeparatorAfterKey(keyValueSeparator: TermName)
            case listAndRecordItemSeparatorOrKeyValueSeparatorOrEndMarker(itemSeparator: TermName, keyValueSeparator: TermName, endMarker: TermName)
            case recordItemSeparatorOrEndMarker(itemSeparator: TermName, endMarker: TermName)
            case type
            case listItem
            case recordItem
            case recordKey
            case listItemOrRecordKey
            case termUIDAndRawFormEndMarker
            case termUID
            
        }
        
        public enum ResourceRequirement {
            
            case system(version: String)
            case applicationByName(name: String)
            case applicationByBundleID(bundleID: String)
            case applescriptLibraryByName(name: String)
            case applescriptAtPath(path: String)
            
        }
        
    }
    
}

/// A predefined parser error that has been passed through a `MessageFormatter`.
/// Has a localized, formatted message.
public struct FormattedParseError: ParseErrorProtocol {
    
    public private(set) var error: ParseError
    
    public let description: String
    
    public init(_ error: ParseError, description: String) {
        self.error = error
        self.description = description
    }
    
    public var location: SourceLocation {
        get {
            error.location
        }
        set {
            error.location = newValue
        }
    }
    public var fixes: [SourceFix] {
        error.fixes
    }
    
}

// MARK: CodableLocalizedError
extension FormattedParseError: CodableLocalizedError {
    
    public var errorDescription: String? {
        description
    }
    
}

/// A custom parser error defined and thrown by parser code in a language module.
/// Its message is formatted at init time and not enumerated anywhere;
/// hence, the error is defined "ad hoc".
public struct AdHocParseError: ParseErrorProtocol {
    
    /// The error message as formatted during init.
    public let description: String
    
    // ParseErrorProtocol
    public var location: SourceLocation
    public let fixes: [SourceFix]
    
    public init(_ description: String, at location: SourceLocation, fixes: [SourceFix] = []) {
        self.description = description
        self.location = location
        self.fixes = fixes
    }
    
}

// MARK: CodableLocalizedError
extension AdHocParseError: CodableLocalizedError {
    
    public var errorDescription: String? {
        description
    }
    
}
