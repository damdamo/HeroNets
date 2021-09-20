//
//  TotalMapTests.swift
//  HeroNetsTests
//
//  Created by Damien Morard on 20.09.21.
//

import XCTest
@testable import HeroNets

class TotalMapTests: XCTestCase {

  enum Keys: CaseIterable {
    case k1, k2
  }
  
  func testBasics() {
    let totalMap = TotalMap<Keys, Int>([.k1: 1, .k2: 2])
    let keys = Set(totalMap.keys)
    let expectedRes: Set<Keys> = [.k1, .k2]
    XCTAssertEqual(keys, expectedRes)
    
    let values = Set(totalMap.values)
    XCTAssertEqual(values, Set([1,2]))
    
    var k: Set<Keys> = []
    var v: Set<Int> = []
    
    for (key, value) in totalMap {
      k.insert(key)
      v.insert(value)
    }
    
    XCTAssertEqual(k, keys)
    XCTAssertEqual(v, values)
  }
  
  func testMapValues() {
    let totalMap = TotalMap<Keys, Int>([.k1: 1, .k2: 2])
    let t = totalMap.mapValues({$0+1})
    let expectedRes = TotalMap<Keys, Int>([.k1: 2, .k2: 3])
    
    XCTAssertEqual(t, expectedRes)
  }

}
