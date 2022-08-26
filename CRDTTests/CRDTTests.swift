//
//  CRDTTests.swift
//  CRDTTests
//
//  Created by Jamie Kelly on 25/08/2022.
//

import XCTest
@testable import CRDT

extension CRDTDict {
    
    func int(_ key: String) -> Int? {
        object(key) as? Int
    }
    
}

class CRDTTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    func testAdd() {
        let dict = CRDTDict()
        let key = "key"
        let item = 100
        dict.set(item, for: key)
        guard let result = dict.int(key) else {
            XCTFail("Failed to lookup result")
            return
        }
        XCTAssert(result == item, "Lookup failed - \(result)")
    }
    
    func testRemove() {
        let dict = CRDTDict()
        let key = "key"
        let item = 100
        dict.set(item, for: key)
        //Assume item was added if testAdd has succeeded.
        dict.remove(for: key)
        XCTAssert(dict.object(key) == nil, "Item was not removed")
    }
    
    func testReplace() {
        let dict = CRDTDict()
        let key = "key"
        let item1 = 100
        let item2 = 101
        dict.set(item1, for: key)
        dict.set(item2, for: key)
        guard let result = dict.int(key) else {
            XCTFail("Failed to lookup result")
            return
        }
        XCTAssert(result == item2, "Lookup failed - \(result)")
    }
    
    func testCopyDict() {
        let key = "key"
        let item1 = 100
        
        let dict1 = CRDTDict()
        dict1.set(item1, for: key)
        
        let dict2 = dict1.copy()
        XCTAssert(dict2.int(key) != nil, "Failed lookup")
        
        //Change object in copied dict.
        let item2 = 101
        dict2.set(item2, for: key)
        
        guard let origResult = dict1.int(key) else {
            XCTFail("Failed to lookup result")
            return
        }
        XCTAssert(origResult == item1, "Item has changed in original dict")
        
        guard let copiedResult = dict2.int(key) else {
            XCTFail("Failed to lookup result")
            return
        }
        
        XCTAssert(copiedResult == item2, "Item has changed in original dict")
    }
   
    func testSimpleMerge() {
        let numberOfItems = 20
        let dict1 = generateIntegerDict(items: numberOfItems)
        let dict2 = dict1.copy()
        
        let testItem = 999
        
        dict1.set(testItem, for: "key3")
        dict2.set(testItem, for: "key5")
        
        let merged = dict1.merge(with: dict2)
        
        for i in 0..<numberOfItems {
            let key = testKey(from: i)
            let expectedItem: Int
            if i == 3 || i == 5 {
                expectedItem = testItem
            }
            else {
                expectedItem = i
            }
            guard let result = merged.int(key) else {
                XCTFail("Lookup failed for key \(key)")
                return
            }
            XCTAssert(result == expectedItem, "Item not as expected")
        }
    }

    func testMergeReplacingItem() {
        let numberOfItems = 20
        let dict1 = generateIntegerDict(items: numberOfItems)
        let dict2 = dict1.copy()
        
        let testItem = 200
        let testItemReplaced = 300
        
        dict1.set(testItem, for: "key3")
        dict2.set(testItemReplaced, for: "key3")
        
        let merged = dict1.merge(with: dict2)
        
        //Assume items which are same in both dicts are merged successfully if `testSimpleMerge` passes.  Just test changes.
        guard let result = merged.int("key3") else {
            XCTFail("Failed lookup")
            return
        }
        XCTAssert(result == testItemReplaced, "Item not replaced correctly -\(result)")
    }
    
    func testMergeIsCommutative() {
        let numberOfItems = 20
        let dict1 = generateIntegerDict(items: numberOfItems)
        let dict2 = dict1.copy()
        
        let key1 = "key1"
        let key2 = "key2"
        
        let testItem1 = 999
        let testItem2 = 888
        
        dict1.set(testItem1, for: key1)
        dict2.set(testItem2, for: key2)
      
        //Merge dicts both ways.
        let merged1 = dict1.merge(with: dict2)
        let merged2 = dict2.merge(with: dict1)
        
        //Assume items which are same in both dicts are merged successfully if `testSimpleMerge` passes.  Just test changes.
        
        //Check first direction merge.
        guard
            let result1 = merged1.int(key1),
            let result2 = merged1.int(key2) else {
            XCTFail("Failed lookup")
            return
        }
        XCTAssert(result1 == testItem1, "Item not replaced correctly -\(result1)")
        XCTAssert(result2 == testItem2, "Item not replaced correctly -\(result2)")
        
        //Check other direction merge.
        guard
            let result1 = merged2.int(key1),
            let result2 = merged2.int(key2) else {
            XCTFail("Failed lookup")
            return
        }
        XCTAssert(result1 == testItem1, "Item not replaced correctly -\(result1)")
        XCTAssert(result2 == testItem2, "Item not replaced correctly -\(result2)")
        
    }
    
    //Tests that a merge applied multiple does not change the result.
    func testMergeIsIdempotent() {
        let numberOfItems = 20
        let dict1 = generateIntegerDict(items: numberOfItems)
        let dict2 = dict1.copy()
        
        let key1 = "key1"
        let key2 = "key2"
        
        let testItem1 = 999
        let testItem2 = 888
        
        dict1.set(testItem1, for: key1)
        dict2.set(testItem2, for: key2)
      
        //Merge one into the other.
        let merged1 = dict1.merge(with: dict2)
        //Merge one into the result.
        let merged2 = merged1.merge(with: dict2)
        
        for i in 0..<numberOfItems {
            let key = testKey(from: i)
            guard
                let result1 = merged1.int(key),
                let result2 = merged2.int(key) else {
                XCTFail("Failed lookup")
                return
            }
            XCTAssert(result1 == result2, "Results do not match - \(result1) != \(result2)")
        }
        
    }    
    
}

extension CRDTTests {
    
    func testKey(from int: Int) -> String {
        return "key\(int)"
    }
    
    /// Creates a dict of keys formatted "key0", "key1", "key2" and so on,
    /// with values being integers from 0 to `count`.
    func generateIntegerDict(items count: Int) -> CRDTDict {
        func key(from int: Int) -> String {
            return "key\(int)"
        }
        let dict = CRDTDict()
        for i in 0..<count {
            let key = key(from: i)
            dict.set(i, for: key)
        }
        return dict
    }
    
}
