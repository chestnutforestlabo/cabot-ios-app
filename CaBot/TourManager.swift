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

import Foundation

protocol TourManagerDelegate {
    func tour(manager: TourManager, destinationChanged: Destination?)
    func tourUpdated(manager: TourManager)
}

class TourManager: TourProtocol {
    var title: String = "No Name"
    var pron: String? = "No Name"
    let id: String = "TourManager"
    var destinations: [Destination] {
        get {
            _destinations
        }
    }
    var currentDestination: Destination? {
        get {
            _currentDestination
        }
    }
    var arrivedDestination: Destination? {
        get {
            _arrivedDestination
        }
    }
    var hasDestination: Bool {
        get {
            return _destinations.count > 0 || _currentDestination != nil
        }
    }
    var destinationCount: Int {
        get {
            _destinations.count + (currentDestination == nil ? 0 : 1)
        }
    }

    private var _destinations: [Destination]
    private var _currentDestination: Destination?
    private var _arrivedDestination: Destination?
    var delegate:TourManagerDelegate?

    init() {
        _destinations = []
    }

    func first(n: Int) -> [Destination] {
        return _destinations[0..<min(_destinations.count, n)].map{ $0 }
    }

    func addToLast(destination: Destination) {
        _destinations.append(destination)
        delegate?.tourUpdated(manager: self)
    }

    func addToFirst(destination: Destination) {
        _destinations.insert(destination, at: 0)
        delegate?.tourUpdated(manager: self)
    }

    func set(tour: TourProtocol) {
        _destinations.removeAll()
        _currentDestination = nil
        _arrivedDestination = nil
        self.title = tour.title
        self.pron = tour.pron
        for d in tour.destinations {
            _destinations.append(d)
        }
        delegate?.tourUpdated(manager: self)
    }

    func cannotStartCurrent() {
        if let cd = _currentDestination {
            addToFirst(destination: cd)
            _currentDestination = nil
            delegate?.tourUpdated(manager: self)
        }
    }

    func stopCurrent() {
        if let cd = _currentDestination {
            addToFirst(destination: cd)
            _currentDestination = nil
            delegate?.tour(manager: self, destinationChanged: nil)
        }
    }

    func arrivedCurrent() {
        _arrivedDestination = _currentDestination
        _currentDestination = nil
        delegate?.tourUpdated(manager: self)
    }

    func clearCurrent() {
        _currentDestination = nil
        delegate?.tourUpdated(manager: self)
        delegate?.tour(manager: self, destinationChanged: nil)
    }

    func clearAll() {
        _destinations.removeAll()
        _currentDestination = nil
        _arrivedDestination = nil
        delegate?.tourUpdated(manager: self)
        delegate?.tour(manager: self, destinationChanged: nil)
    }

    func nextDestination() {
        if _destinations.count == 0  {
            self._currentDestination = nil
            delegate?.tourUpdated(manager: self)
            //delegate?.tour(manager: self, destinationChanged: nil)
            return
        }
        self._arrivedDestination = nil
        self._currentDestination = pop()
        delegate?.tourUpdated(manager: self)
        delegate?.tour(manager: self, destinationChanged: currentDestination)
    }

    func pop() -> Destination {
        return _destinations.removeFirst()
    }
}
