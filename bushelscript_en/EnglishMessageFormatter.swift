import Bushel

public final class EnglishMessageFormatter: MessageFormatter {
    
    public init() {
    }
    
    public func message(for error: ParseError) -> String {
        switch error.error {
        case let .missing(elements, context):
            return "Expected " + elements.map { element in
                switch element {
                case let .keyword(keyword):
                    return "\(keyword)"
                case .termName:
                    return "term name"
                case .resourceName:
                    return "resource name"
                case .variableName:
                    return "variable name"
                case .functionName:
                    return "function name"
                case .expression:
                    return "expression"
                case .lineBreak:
                    return "line break"
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
                case let .term(role):
                    return role.map { "\($0) " } ?? "term"
                case .listItem:
                    return "list item"
                case .recordItem:
                    return "record item"
                case .recordKey:
                    return "record key"
                case .termRole:
                    return "term role"
                case .termURIAndRawFormEndMarker:
                    return "term URI followed by ‘»’"
                case .termURI:
                    return "term URI"
                case .weaveDelimiter:
                    return "weave delimiter"
                case .weaveDelimiterEndMarker:
                    return "‘)’ to end weave delimiter"
                case .blockBody:
                    return "block body (‘do’)"
                case .specifier:
                    return "specifier"
                }
            }.joined(separator: " or ") + (context.map { context in
                switch context {
                case let .adHoc(context):
                    return " \(context)"
                case let .afterKeyword(keyword):
                    return " after \(keyword)"
                case .afterInfixOperator:
                    return " after infix operator"
                case .afterPrefixOperator:
                    return " after prefix operator"
                case .afterPostfixOperator:
                    return " after postfix operator"
                case .afterSequencedExpression:
                    return " after sequenced expression"
                case let .toBeginBlock(blockType):
                    return " to begin \(blockType)"
                }
            } ?? "")
        case let .unmetResourceRequirement(requirement):
            switch requirement {
            case let .system(version):
                let actualVersion = ProcessInfo.processInfo.operatingSystemVersionString
                return "Your system is version \(actualVersion), but this script requires at least \(version)"
            case let .applicationByName(name):
                return "Can't find required app \(name)"
            case let .applicationByBundleID(bundleID):
                return "Can't find required app with ID \(bundleID)"
            case let .libraryByName(name):
                return "Can't find required library \(name)"
            case let .applescriptAtPath(path):
                return "Can't find AppleScript script at path \(path)"
            }
        case let .invalidResourceType(validTypes):
            let formattedTypeNames = validTypes
                .map { $0.normalized }
                .joined(separator: ", ")
            return "Invalid resource type; valid types are: \(formattedTypeNames)"
        case let .terminologyImportFailure(error):
            return "Failed to import terminology: \(error)"
        case .quotedResourceTerm:
            return "This expression binds a resource term, remove the quotation marks"
        case .invalidString:
            return "Failed to parse string"
        case .invalidNumber:
            return "Failed to parse number"
        case .undefinedTerm:
            return "No such term is defined"
        case .mismatchedPipe:
            return "Mismatched | character"
        case .invalidTermRole:
            return "Invalid term role"
        case .wrongTermRoleForContext:
            return "Term role is unsuitable for this context"
        }
    }
    
}
