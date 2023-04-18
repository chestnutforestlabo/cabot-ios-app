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
import SwiftUI
import CoreBluetooth

enum ConnectionType:String, CaseIterable{
    case BLE = "ble"
    case TCP = "tcp"
}

protocol CaBotServiceProtocol {
    func activityLog(category: String, text: String, memo: String) -> Bool
    func send(destination: String) -> Bool
    func summon(destination: String) -> Bool
    func manage(command: CaBotManageCommand) -> Bool
    func isConnected() -> Bool
}

protocol CaBotTransportProtocol: CaBotServiceProtocol {
    func connectionType() -> ConnectionType
    func startAdvertising()
    func stopAdvertising()
}

protocol CaBotServiceDelegate {
    func caBot(service:any CaBotTransportProtocol, centralConnected:Bool)
    func caBot(service:any CaBotTransportProtocol, versionMatched:Bool, with:String)
    func cabot(service:any CaBotTransportProtocol, openRequest:URL)
    func cabot(service:any CaBotTransportProtocol, soundRequest:String)
    func cabot(service:any CaBotTransportProtocol, notification:NavigationNotification)
    func cabot(service:any CaBotTransportProtocol, deviceStatus:DeviceStatus)
    func cabot(service:any CaBotTransportProtocol, systemStatus:SystemStatus)
    func cabot(service:any CaBotTransportProtocol, batteryStatus:BatteryStatus)
}

enum NavigationNotification:String {
    case next
    case arrived
    case subtour
    case skip
}

enum CaBotManageCommand:String {
    case reboot
    case poweroff
    case start
    case stop
}

struct DeviceStatus: Decodable {
    init(){
        level = .Unknown
        devices = []
    }
    var level: DeviceStatusLevel
    var devices: [DeviceStatusEntry]
}

struct DeviceStatusEntry: Decodable, Hashable {
    var type: String
    var model: String
    var level: DeviceStatusLevel
    var message: String
    var values: [DiagnosticStatusKeyValue]

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(model)
        hasher.combine(level)
        hasher.combine(message)
    }
}

enum DeviceStatusLevel:String, Decodable {
    case OK
    case Error
    case Unknown

    var icon: String {
        get {
            switch (self) {
            case .OK:
                return "checkmark.circle"
            case .Error:
                return "xmark.circle"
            case .Unknown:
                return "questionmark.circle"
            }
        }
    }
    var color: Color? {
        switch (self) {
        case .OK:
            return Color.blue
        case .Error:
            return Color.red
        case .Unknown:
            return Color.gray
        }
    }
}

struct SystemStatus: Decodable {
    init(){
        level = .Unknown
        diagnostics = []
    }
    var level: CaBotSystemLevel
    var diagnostics: [DiagnosticStatus]
}

enum CaBotSystemLevel:String, Decodable {
    case Unknown
    case Inactive
    case Active
    case Activating
    case Deactivating
    case Error

    var icon: String {
        switch (self) {
        case .Active:
            return "checkmark.circle"
        case .Inactive:
            return "sleep"
        case .Error:
            return "xmark.circle"
        case .Unknown:
            return "questionmark.circle"
        case .Activating:
            return "hourglass"
        case .Deactivating:
            return "hourglass"
        }
    }

    var color: Color? {
        switch (self) {
        case .Active, .Inactive:
            return Color.blue
        case .Activating, .Deactivating:
            return Color.orange
        case .Error:
            return Color.red
        case .Unknown:
            return Color.gray
        }
    }
}

struct DiagnosticStatusKeyValue: Decodable, Equatable, Hashable {
    var key: String
    var value: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }
}

struct DiagnosticStatus: Decodable, Hashable {
    var level: DiagnosticLevel
    var name: String
    var hardware_id: String
    var message: String
    var values: [DiagnosticStatusKeyValue]

    init(name: String) {
        self.level = .Stale
        self.name = name
        self.hardware_id = ""
        self.message = ""
        self.values = []
    }

    var componentName: String {
        get {
            if let last = name.split(separator: "/").last {
                return String(last)
            }
            return name
        }
    }
    var rootName: String? {
        get {
            if let first = name.split(separator: "/").first {
                let root = String(first)
                if root == componentName {
                    return nil
                }
                return root
            }
            return name
        }
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(hardware_id)
    }
}

struct BatteryStatus: Decodable {
    init(){
        level = .Stale
        name = "Battery"
        hardware_id = ""
        message = "Unknown"
        values = []
    }
    var level: DiagnosticLevel
    var name: String
    var hardware_id: String
    var message: String
    var values: [DiagnosticStatusKeyValue]
}

enum DiagnosticLevel: Int, Decodable {
    case OK = 0
    case Warning = 1
    case Error = 2
    case Stale = 3

    var text: String {
        switch (self) {
        case .OK:
            return "OK"
        case .Warning:
            return "Warning"
        case .Error:
            return "Error"
        case .Stale:
            return "Stale"
        }
    }

    var icon: String {
        switch (self) {
        case .OK:
            return "checkmark.circle"
        case .Warning:
            return "exclamationmark.triangle"
        case .Error:
            return "xmark.circle"
        case .Stale:
            return "questionmark.circle"
        }
    }

    var color: Color? {
        switch (self) {
        case .OK:
            return Color.blue
        case .Warning:
            return Color.orange
        case .Error:
            return Color.red
        case .Stale:
            return Color.gray
        }
    }
}

struct SpeakRequest: Decodable {
    var request_id: Int64
    var text: String = ""
    var rate: Int8 = 0
    var pitch: Int8 = 0
    var volume: Int8 = 0
    var lang: String = ""
    var voice: String = ""
    var force: Bool = false
    var priority: Int32 = 0
    var timeout: Float32 = 0
    var channels: Int8 = 0
}

enum NavigationEventType:String, Decodable {
    case next
    case arrived
    case content
    case sound
    case subtour
    case skip
    case unknown
}

struct NavigationEventRequest: Decodable {
    var request_id: Int64
    var type: NavigationEventType = .unknown
    var param: String = ""
}

class CaBotServiceActions {
    static let shared = CaBotServiceActions()
    private init() {
    }

    private var lastSpeakRequestID: Int64 = 0
    private var lastNavigationEventRequestID: Int64 = 0

    func handle(service: CaBotTransportProtocol, delegate: CaBotServiceDelegate, tts: CaBotTTS, request: SpeakRequest) {
        // noop for same request ID from different transport
        guard lastSpeakRequestID < request.request_id else { return }
        lastSpeakRequestID = request.request_id

        DispatchQueue.main.async {
            if request.force {
                tts.stop()
            }
            let line = request.text
            let force = request.force
            if !tts.isSpeaking {
                _ = service.activityLog(category: "ble speech request speaking", text: String(line), memo: "force=\(force)")
                tts.speak(String(line)) { code in
                    if code > 0 {
                        _ = service.activityLog(category: "ble speech request completed", text: String(line), memo: "force=\(force),return_code=\(code)")
                    } else {
                        _ = service.activityLog(category: "ble speech request canceled", text: String(line), memo: "force=\(force),return_code=\(code)")
                    }
                }
            } else {
                NSLog("TTS is busy and skip speaking: \(line)")
                _ = service.activityLog(category: "ble speech request skipped", text: String(line), memo: "TTS is busy")
            }

        }
    }

    func handle(service: CaBotTransportProtocol, delegate: CaBotServiceDelegate, request: NavigationEventRequest) {
        // noop for same request ID from different transport
        guard lastNavigationEventRequestID < request.request_id else { return }
        lastNavigationEventRequestID = request.request_id

        DispatchQueue.main.async {
            switch(request.type) {
            case .next, .arrived, .subtour, .skip:
                if let note = NavigationNotification(rawValue: request.type.rawValue) {
                    delegate.cabot(service: service, notification: note)
                } else {
                    NSLog("Unknown navigation notification type %@", request.type.rawValue)
                }
            case .content:
                guard let url = URL(string: request.param) else {
                    return
                }
                delegate.cabot(service: service, openRequest: url)
            case .sound:
                delegate.cabot(service: service, soundRequest: request.param)
            case .unknown:
                break
            }
        }
    }
}
