import Foundation

public enum Resource {
    
    case applicationByName(Located<ApplicationNameTerm>)
    case applicationByID(Located<ApplicationIDTerm>)
    
}
