/*******************************************************************************
 * Copyright (c) 2021  Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/


import XCTest
@testable import CaBot

class CaBotTests: XCTestCase {
    static func getSource(_ name: String, withExtension: String) -> Source {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: withExtension, subdirectory: "data")!
        return Source(base: url.deletingLastPathComponent(), type: .local, src: url.lastPathComponent, i18n: I18N.shared)
    }
    
    override func setUp() {
    }

    override func tearDown() {
    }

    func testParseDestinationYaml() {
        if let destinations = try? Destination.load(at: Self.getSource("destinations", withExtension: "yaml")) {
            assert(destinations[0].error == nil)
            
            print("-------------------")
            assert(destinations[1].error != nil)
            print(destinations[1].error!)
            print("-------------------")
            assert(destinations[2].error != nil)
            print(destinations[2].error!)
            print("-------------------")
            assert(destinations[3].error != nil)
            print(destinations[3].error!)
            print("-------------------")
            assert(destinations[4].error == nil)
            assert(destinations[4].subtour != nil)
            print(destinations[4].subtour!)
            print("-------------------")
            assert(destinations[5].error == nil)
            assert(destinations[5].subtour != nil)
            print(destinations[5].subtour!)
            print("-------------------")
            assert(destinations[6].error != nil)
            print(destinations[6].error!)
            print("-------------------")
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
