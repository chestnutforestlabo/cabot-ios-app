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

import SwiftUI
import CoreBluetooth
import CoreLocation
import HealthKit
import os.log

// override NSLog
public func NSLog(_ format: String, _ args: CVarArg...) {
    withVaList(args) { NavNSLogv(format, $0) }
}

@main
struct CaBotApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    var modelData: CaBotAppModel = CaBotAppModel(preview: false)

    init() {
        #if ATTEND
            modelData.modeType = .Advanced
        #elseif USER
            modelData.modeType = .Normal
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(modelData)
        }.onChange(of: scenePhase) { newScenePhase in

            modelData.onChange(of: newScenePhase)

            switch newScenePhase {
            case .background:
                break
            case .inactive:
                break
            case .active:
                let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
                if isVoiceOverRunning {
                    modelData.stopSpeak()
                }
                Logging.stopLog()
                Logging.startLog(true)
                break
            @unknown default:
                break
            }
        }
    }
}
