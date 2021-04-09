
/// Formats error messages.
public protocol MessageFormatter {
    
    func message(for error: ParseError) -> String
    
    init()
    
}

// MARK: Consumer interface
extension MessageFormatter {
    
    public func format(error: ParseErrorProtocol) -> ParseErrorProtocol {
        if let error = error as? ParseError {
            return format(error: error)
        } else {
            return error
        }
    }
    
    public func format(error: ParseError) -> FormattedParseError {
        FormattedParseError(error, description: message(for: error))
    }
    
}
