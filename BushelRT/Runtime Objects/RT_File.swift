import Bushel
import SwiftAutomation

/// A file URL.
public class RT_File: RT_Object {
    
    public var value: URL
    
    public init(value: URL) {
        self.value = value
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(.date)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public var basename: RT_String {
        RT_String(value: value.deletingPathExtension().lastPathComponent)
    }
    public var extname: RT_String {
        RT_String(value: value.pathExtension)
    }
    public var dirname: RT_String {
        RT_String(value: value.deletingLastPathComponent().path)
    }
    
    public override var properties: [RT_Object] {
        super.properties + [basename, extname, dirname]
    }
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(property.typedUID) {
        case .file_basename:
            return basename
        case .file_extname:
            return extname
        case .file_dirname:
            return dirname
        default:
            return try super.property(property)
        }
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        (other as? RT_File).map { value == $0.value } ?? false
    }
    
}

// MARK: AEEncodable
extension RT_File: AEEncodable {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(fileURL: value)
    }
    
}

extension RT_File {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
