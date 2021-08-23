import Foundation

func executeSyncOnMainThread<Result>(execute work: () throws -> Result) rethrows -> Result {
    if Thread.current.isMainThread {
        return try work()
    } else {
        return try DispatchQueue.main.sync(execute: work)
    }
}
