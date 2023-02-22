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

protocol CaBotTransportProtocol{
    func activityLog(category: String, text: String, memo: String) -> Bool
    func send(destination: String) -> Bool
    func summon(destination: String) -> Bool
    func find(person: String) -> Bool
    func manage(command: CaBotManageCommand) -> Bool
    func startAdvertising()
    func stopAdvertising()
    func notifyDeviceStatus(status: DeviceStatus)
    func notifySystemStatus(status: SystemStatus)
    func notifyBatteryStatus(status: BatteryStatus)
}

protocol CaBotServiceDelegate {
    func caBot(service:CaBotTransportProtocol, versionMatched:Bool, with:String)
    func caBot(service:CaBotTransportProtocol, faceappConnected:Bool)
    func cabot(service:CaBotTransportProtocol, openRequest:URL)
    func cabot(service:CaBotTransportProtocol, soundRequest:String)
    func cabot(service:CaBotTransportProtocol, notification:NavigationNotification)
    func cabot(service:CaBotTransportProtocol, deviceStatus:DeviceStatus)
    func cabot(service:CaBotTransportProtocol, systemStatus:SystemStatus)
    func cabot(service:CaBotTransportProtocol, batteryStatus:BatteryStatus)
    func caBot(service:CaBotTransportProtocol, centralConnected:Bool)
}

enum NavigationNotification:String {
    case next
    case arrived
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
