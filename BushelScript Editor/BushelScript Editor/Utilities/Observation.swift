// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

final class NotificationObservation: NSObject, Tiable {
    
    private var observation: NSObjectProtocol
    private var lifetimeAssociation: LifetimeAssociation?
    
    init<Object: AnyObject>(_ name: Notification.Name, _ object: Object? = nil, queue: OperationQueue? = .main, handler: @escaping (Object?, [UserInfo : Any]) -> Void) {
        observation = NotificationCenter.default.addObserver(forName: name, object: object, queue: queue, using: {
            handler($0.object as! Object?, $0.userInfo.map { [UserInfo : Any](uniqueKeysWithValues:
                $0.compactMap { keyValue in
                    (keyValue.key as? UserInfo).flatMap {
                        ($0, keyValue.value)
                    }
                }
            )} ?? [:])
        })
    }
    
    func tie(to owner: AnyObject) -> Self {
        lifetimeAssociation = LifetimeAssociation(of: self, with: owner, deinitHandler: { [weak self] in
            if let self = self {
                NotificationCenter.default.removeObserver(self.observation)
            }
        })
        return self
    }
    
}

func tie<T: Tiable>(to owner: AnyObject, _ tiables: [T]) {
    for tiable in tiables {
        tiable.tie(to: owner)
    }
}

protocol Tiable {
    
    @discardableResult
    func tie(to owner: AnyObject) -> Self
    
}

// The following portions of this file are copied from sindresorhus/Defaults.
// (It was my pull request that added LifetimeAssociation.)

final class ObjectAssociation<T: Any> {
    subscript(index: AnyObject) -> T? {
        get {
            objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T?
        }
        set {
            objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}


/**
Causes a given target object to live at least as long as a given owner object.
*/
final class LifetimeAssociation {
    private class ObjectLifetimeTracker {
        var object: AnyObject?
        var deinitHandler: () -> Void

        init(for object: AnyObject, deinitHandler: @escaping () -> Void) {
            self.object = object
            self.deinitHandler = deinitHandler
        }

        deinit {
            deinitHandler()
        }
    }

    private static let associatedObjects = ObjectAssociation<[ObjectLifetimeTracker]>()
    private weak var tracker: ObjectLifetimeTracker?
    private weak var owner: AnyObject?

    /**
    Causes the given target object to live at least as long as either the given owner object or the resulting `LifetimeAssociation`, whichever is deallocated first.

    When either the owner or the new `LifetimeAssociation` is destroyed, the given deinit handler, if any, is called.

    ```
    class Ghost {
        var association: LifetimeAssociation?

        func haunt(_ host: Furniture) {
            association = LifetimeAssociation(of: self, with: host) { [weak self] in
                // Host has been deinitialized
                self?.haunt(seekHost())
            }
        }
    }

    let piano = Piano()
    Ghost().haunt(piano)
    // The Ghost will remain alive as long as `piano` remains alive.
    ```

    - Parameter target: The object whose lifetime will be extended.
    - Parameter owner: The object whose lifetime extends the target object's lifetime.
    - Parameter deinitHandler: An optional closure to call when either `owner` or the resulting `LifetimeAssociation` is deallocated.
    */
    init(of target: AnyObject, with owner: AnyObject, deinitHandler: @escaping () -> Void = {}) {
        let tracker = ObjectLifetimeTracker(for: target, deinitHandler: deinitHandler)

        let associatedObjects = LifetimeAssociation.associatedObjects[owner] ?? []
        LifetimeAssociation.associatedObjects[owner] = associatedObjects + [tracker]

        self.tracker = tracker
        self.owner = owner
    }

    /**
    Invalidates the association, unlinking the target object's lifetime from that of the owner object. The provided deinit handler is not called.
    */
    func cancel() {
        tracker?.deinitHandler = {}
        invalidate()
    }

    deinit {
        invalidate()
    }

    private func invalidate() {
        guard
            let owner = owner,
            let wrappedObject = tracker,
            var associatedObjects = LifetimeAssociation.associatedObjects[owner],
            let wrappedObjectAssociationIndex = associatedObjects.firstIndex(where: { $0 === wrappedObject })
        else {
            return
        }

        associatedObjects.remove(at: wrappedObjectAssociationIndex)
        LifetimeAssociation.associatedObjects[owner] = associatedObjects
        self.owner = nil
    }
}
