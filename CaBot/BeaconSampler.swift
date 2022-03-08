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
import CoreLocation

class BeaconSampler: NSObject, CLLocationManagerDelegate {
    let manager:CLLocationManager = CLLocationManager()
    let uuids:[UUID]
    let block:([CLBeacon]) -> Void

    var starting: Bool = false
    var timer:Timer?
    var beacons:[CLBeacon] = []
    var waitCount:Int = 0

    init(with uuids:[UUID], block: @escaping ([CLBeacon]) -> Void) {
        self.uuids = uuids
        self.block = block
        super.init()

        manager.delegate = self
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if starting {
            start()
            starting = false
        }
    }

    func start() {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            stop()
            for uuid in uuids {
                manager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid))
            }
            waitCount = 3
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if self.beacons.count == 0 && self.waitCount > 0{
                    self.waitCount -= 1
                    return
                }
                self.block(self.beacons)
                self.waitCount = 3
                self.beacons.removeAll()
            }
        } else {
            starting = true
            manager.requestAlwaysAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        self.beacons.append(contentsOf: beacons)
    }

    func stop() {
        starting = false
        for c in manager.rangedBeaconConstraints {
            manager.stopRangingBeacons(satisfying: c)
        }
        timer?.invalidate()
    }
}
