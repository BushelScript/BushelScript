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
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [
            PropertyInfo(Properties.file_basename): \RT_File.basename,
            PropertyInfo(Properties.file_extname): \RT_File.extname,
            PropertyInfo(Properties.file_dirname): \RT_File.dirname,
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
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
