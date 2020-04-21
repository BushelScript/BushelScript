import BushelLanguage
import Bushel

public final class EnglishMessageFormatter: BushelLanguage.MessageFormatter {
    
    public init() {
    }
    
    public func message(for error: ParseError) -> String {
        switch error.error {
        case let .missing(expectation):
            return "expected " + {
                switch expectation {
                case .resourceName:
                    return "resource name"
                case let .endTagOrLineBreak(endTag):
                    return "‘\(endTag)’ or line break"
                case let .expressionAfterKeyword(keyword):
                    return "expression after ‘\(keyword)’"
                case .lineBreakAfterSequencedExpression:
                    return "line break after sequenced expression"
                case .expressionAfterBinaryOperator:
                    return "expression after binary operator"
                case .expressionAfterPrefixOperator:
                    return "expression after prefix operator"
                case .expressionAfterPostfixOperator:
                    return "expression after postfix operator"
                case let .groupedExpressionAfterBeginMarker(beginMarker):
                    return "grouped expression after ‘\(beginMarker)’"
                case let .groupedExpressionEndMarker(endMarker):
                    return "‘\(endMarker)’ to end grouped expression"
                case let .recordKeyBeforeKeyValueSeparatorOrEndMarkerAfter(keyValueSeparator, endMarker):
                    return "key expression before ‘\(keyValueSeparator)’, or ‘\(endMarker)’ after for an empty record"
                case let .listItemSeparatorOrEndMarker(itemSeparator, endMarker):
                    return "‘\(endMarker)’ to end list or ‘\(itemSeparator)’ to separate additional items"
                case let .recordKeyValueSeparatorAfterKey(keyValueSeparator):
                    return "‘\(keyValueSeparator)’ after key in record"
                case let .listAndRecordItemSeparatorOrKeyValueSeparatorOrEndMarker(itemSeparator, keyValueSeparator, endMarker):
                    return "‘\(endMarker)’ to end list, ‘\(itemSeparator)’ to separate additional items or ‘\(keyValueSeparator)’ to make a record"
                case let .recordItemSeparatorOrEndMarker(itemSeparator, endMarker):
                    return "‘\(endMarker)’ to end record or ‘\(itemSeparator)’ to separate additional items"
                case .type:
                    return "type"
                case .listItem:
                    return "list item"
                case .recordItem:
                    return "record item"
                case .recordKey:
                    return "record key"
                case .listItemOrRecordKey:
                    return "list item or record key"
                case .termUIDAndRawFormEndMarker:
                    return "expected term UID followed by ‘»’"
                case .termUID:
                    return "expected term UID"
                }
            }()
        case let .unmetResourceRequirement(requirement):
            switch requirement {
            case let .system(version):
                let actualVersion = ProcessInfo.processInfo.operatingSystemVersionString
                return "this script requires an operating system version of at least \(version); your system is running \(actualVersion)"
            case let .applicationByName(name):
                return "this script requires the application “\(name)”, which was not found on your system"
            case let .applicationByBundleID(bundleID):
                return "this script requires an application with identifier “\(bundleID)”, which was not found on your system"
            case let .applescriptLibraryByName(name):
                return "this script requires the AppleScript library “\(name)”, which was not found on your system"
            case let .applescriptAtPath(path):
                return "this script requires an AppleScript script at path “\(path)”, which was not found on your system"
            }
        case let .invalidResourceType(validTypes):
            let formattedTypeNames = validTypes
                .map { $0.normalized }
                .joined(separator: ", ")
            return "invalid resource type; valid types are: \(formattedTypeNames)"
        case let .terminologyImportFailure(error):
            return "an error occurred while importing terminology: \(error)"
        case .quotedResourceTerm:
            return "this binds a resource term; remove the quotation mark(s)"
        case .invalidString:
            return "unable to parse string"
        case .invalidNumber:
            return "unable to parse number"
        case .undefinedTerm:
            return "no such term is defined"
        case .mismatchedPipe:
            return "mismatched ‘|’"
        case .invalidTermType:
            return "invalid term type"
        case .rawFormTermNotConstructible:
            return "this term is undefined and cannot be ad-hoc constructed"
        case .wrongTermTypeForContext:
            return "wrong type of term for context"
        }
    }
    
}
