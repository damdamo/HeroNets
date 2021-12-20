import XCTest
import DDKit

class MFDDFactoryTests: XCTestCase {

  func testConcatAndFilterInclude() {

    let factory = MFDDFactory<String, Int>()

    var expectation = factory.encode(family: [["x": 2, "y": 2, "z": 3], ["x": 2, "y": 3, "z": 3]])
    var mfdd1 = factory.encode(family: [["y": 2, "z": 3], ["y": 3, "z": 3]])
    var mfdd2 = factory.encode(family: [["x": 2, "z": 3], ["x": 2, "z": 4]])
    var res = factory.concatAndFilterInclude(mfdd1.pointer, mfdd2.pointer)
    var mfdd = MFDD(pointer: res, factory: factory)

    XCTAssertEqual(mfdd, expectation)

    expectation = factory.encode(family: [["x": 1, "y": 1], ["x": 1, "y": 2], ["x": 3, "y": 1], ["x": 3, "y": 2]])
    mfdd1 = factory.encode(family: [["x": 1], ["x": 3]])
    mfdd2 = factory.encode(family: [["y": 1], ["y": 2]])
    res = factory.concatAndFilterInclude(mfdd1.pointer, mfdd2.pointer)
    mfdd = MFDD(pointer: res, factory: factory)

    XCTAssertEqual(mfdd, expectation)

    expectation = factory.encode(family: [["x": 1, "y": 2]])
    mfdd1 = factory.encode(family: [["x": 1], ["x": 2], ["x": 3]])
    mfdd2 = factory.encode(family: [["x": 1, "y": 2]])
    res = factory.concatAndFilterInclude(mfdd1.pointer, mfdd2.pointer)
    mfdd = MFDD(pointer: res, factory: factory)

    XCTAssertEqual(mfdd, expectation)

    expectation = factory.encode(family: [["x": 1, "y": 1, "z": 1], ["x": 1, "y": 1, "z": 2]])
    mfdd1 = factory.encode(family: [["x": 1, "y": 1], ["x": 1, "y": 2]])
    mfdd2 = factory.encode(family: [["y": 1, "z": 1], ["y": 1, "z": 2]])
    res = factory.concatAndFilterInclude(mfdd1.pointer, mfdd2.pointer)
    mfdd = MFDD(pointer: res, factory: factory)

    XCTAssertEqual(mfdd, expectation)

    expectation = factory.encode(family: [["x": 1, "y": 2, "z": 2], ["x": 2, "y": 1, "z": 1]])
    mfdd1 = factory.encode(family: [["x": 1, "y": 2], ["x": 2, "y": 1]])
    mfdd2 = factory.encode(family: [["x": 1, "z": 2], ["x": 2, "z": 1]])
    res = factory.concatAndFilterInclude(mfdd1.pointer, mfdd2.pointer)
    mfdd = MFDD(pointer: res, factory: factory)

    print(mfdd)
    print(expectation)

    XCTAssertEqual(mfdd, expectation)

  }

}
