// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Darwin
import Foundation

extension String {
    
    struct ReadError: LocalizedError {
        
        var path: String
        var errorNumber: Int32
        
        var errorDescription: String? {
            "Can't read \(path): \(String(cString: strerror(errorNumber)))"
        }
        
    }
    
    static func read(fromPath path: String) throws -> String {
        var result = ""
        guard let stream = fopen(path, "r") else {
            throw ReadError(path: path, errorNumber: errno)
        }
        var buffer = [CChar](repeating: 0, count: 512)
        try buffer.withUnsafeMutableBufferPointer { buffer in
            let base = buffer.baseAddress!
            while fgets(base, Int32(buffer.count), stream) != nil {
                result += String(cString: base)
            }
            guard feof(stream) != 0 else {
                throw ReadError(path: path, errorNumber: ferror(stream))
            }
        }
        return result
    }
    
}
