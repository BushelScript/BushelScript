import Bushel
import AEthereal

/// A file URL.
public class RT_File: RT_Object {
    
    public var value: URL
    
    public init(_ rt: Runtime, value: URL) {
        self.value = value
        super.init(rt)
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    public override class var staticType: Types {
        .file
    }
    
    public var basename: RT_String {
        RT_String(rt, value: value.deletingPathExtension().lastPathComponent)
    }
    public var extname: RT_String {
        RT_String(rt, value: value.pathExtension)
    }
    public var dirname: RT_String {
        RT_String(rt, value: value.deletingLastPathComponent().path)
    }
    
    public override class var propertyKeyPaths: [Properties : AnyKeyPath] {
        [
            .file_basename: \RT_File.basename,
            .file_extname: \RT_File.extname,
            .file_dirname: \RT_File.dirname
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        switch Types(type.id) {
        case .string:
            return RT_String(rt, value: value.path)
        default:
            return super.coerce(to: type)
        }
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        (other as? RT_File).map { value == $0.value } ?? false
    }
    
}

// MARK: AEEncodable
extension RT_File: AEEncodable {
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(fileURL: value)
    }
    
}

extension RT_File {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
