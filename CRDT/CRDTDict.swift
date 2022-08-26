//
//  CRDTDict.swift
//  CRDT
//
//  Created by Jamie Kelly on 25/08/2022.
//

import Foundation
import SwiftUI

class CRDTDict {
    
    init(bias: Bias = .added) {
        self.bias = bias
        self.added = [String: Element]()
        self.removed = [String: Element]()
    }
    
    func object(_ key: String) -> Any? {
        _object(key)
    }
    
    func set(_ object: Any, for key: String) {
        _set(object, for: key)
    }
    
    func remove(for key: String) {
        _remove(for: key)
    }
    
    func merge(with other: CRDTDict) -> CRDTDict {
        _merge(with: other)
    }
    
    func copy() -> CRDTDict {
        return CRDTDict(bias: self.bias,
                        added: self.added,
                        removed: self.removed)
    }
    
    //Determines behvaiour given an element for a given key has been added and removed in
    //two dictionaries at the exact same time.
    enum Bias {
        //The added element will be returned.
        case added
        //No element will be returned - the element will be considered to have been removed.
        case removed
    }
    
    
    //MARK: - Private
    
    private let bias: Bias
    
    private init(bias: Bias = .added,
                 added: [String: Element]? = nil,
                 removed: [String: Element]? = nil) {
        self.bias = bias
        self.added = added ?? [String: Element]()
        self.removed = removed ?? [String: Element]()
    }
    
    private struct Element {
        let updatedAt: TimeInterval
        let item: Any
        
        init(item: Any) {
            self.updatedAt = Date().timeIntervalSince1970
            self.item = item
        }
    }
    
    private var added: [String: Element]
    private var removed: [String: Element]
    
    private var addLock = NSLock()
    private var removeLock = NSLock()

    func _set(_ object: Any, for key: String) {
        addLock.lock()
        let toAdd = Element(item: object)
        if
            let existing = added[key],
            toAdd.updatedAt < existing.updatedAt {
            return
        }
        added[key] = Element(item: object)
        addLock.unlock()
    }
    
    func _remove(for key: String) {
        removeLock.lock()
        
        guard let existing = lookUpElement(key) else {
            //Item has already been removed or never existed.
            return
        }
        
        let toRemove = Element(item: existing.item)
        if
            let existing = removed[key],
            toRemove.updatedAt < existing.updatedAt {
            return
        }
        removed[key] = Element(item: object)
        removeLock.unlock()
    }
    
    func _object(_ key: String) -> Any? {
        return lookUpElement(key)?.item
    }
    
    private func lookUpElement(_ key: String) -> Element? {
        /*
         An element is a member of the LWW-Element-Set if it is in the add set, and either not in the remove set, or in the remove set but with an earlier timestamp than the latest timestamp in the add set.
         */
        guard let addedElement = added[key] else {
            return nil
        }
        if let removedElement = removed[key] {
            if removedElement.updatedAt < addedElement.updatedAt {
                return addedElement
            }
            else if removedElement.updatedAt == addedElement.updatedAt {
                if bias == .added {
                    return addedElement
                }
            }
            return nil
        }
        return addedElement
    }
    
   
    func _merge(with other: CRDTDict) -> CRDTDict {
        addLock.lock()
        removeLock.lock()
        other.addLock.lock()
        other.removeLock.lock()
        
        /*
         Merging two replicas of the LWW-Element-Set consists of taking the union of the add sets and the union of the remove sets.
         */
        let mergedAdded = added.merging(other.added) {
            $0.updatedAt >= $1.updatedAt ? $0 : $1
        }
        let mergedRemoved = removed.merging(other.removed) {
            $0.updatedAt >= $1.updatedAt ? $0 : $1
        }
        addLock.unlock()
        removeLock.unlock()
        other.addLock.unlock()
        other.removeLock.unlock()
        return CRDTDict(bias: self.bias,
                        added: mergedAdded,
                        removed: mergedRemoved)
    }
    

}
