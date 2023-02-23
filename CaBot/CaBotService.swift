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


import Collections
import Foundation
import CoreBluetooth
import HLPDialog
import Gzip
import UIKit
import SwiftUI

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

protocol CaBotServiceDelegate {
    func caBot(service:CabotTransportProtocol, versionMatched:Bool, with:String)

    func caBot(service:CabotTransportProtocol, faceappConnected:Bool)

    func cabot(service:CabotTransportProtocol, openRequest:URL)
    func cabot(service:CabotTransportProtocol, soundRequest:String)
    func cabot(service:CabotTransportProtocol, notification:NavigationNotification)
    func cabot(service:CabotTransportProtocol, deviceStatus:DeviceStatus)
    func cabot(service:CabotTransportProtocol, systemStatus:SystemStatus)
    func cabot(service:CabotTransportProtocol, batteryStatus:BatteryStatus)
    func caBot(service:CabotTransportProtocol, centralConnected:Bool)
}

protocol CaBotServiceDelegateBlueTooth : CaBotServiceDelegate{
    func cabot(service:CabotTransportProtocol, bluetoothStateUpdated: CBManagerState)
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
protocol CabotTransportProtocol{

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


class CaBotService: NSObject, CBPeripheralManagerDelegate, CabotTransportProtocol {
    
    
    static let CABOT_BLE_VERSION = "20220320"
    static let UUID_FORMAT = "35CE%04X-5E89-4C0D-A3F6-8A6A507C1BF1"
    static let CABOT_SPEED_CONFIG = "cabot_speed"
    static let SPEECH_SPEED_CONFIG = "speech_speed"
    static let CONTRIAL_MAX = 5

    func generateUUID(handle:Int) -> CBUUID {
        return CBUUID(string: String(format:CaBotService.UUID_FORMAT, handle))
    }

    fileprivate var tts:CaBotTTS
    var delegate:CaBotServiceDelegateBlueTooth?
    
    init(with tts:CaBotTTS) {
        self.tts = tts
    }


    public var teamID:String? = nil
    public var faceappReady:Bool = false
    public var peripheralManager:CBPeripheralManager?

    private let uuid = CBUUID(string: String(format:UUID_FORMAT, 0x0000))
    private var logChar:CaBotNotifyChar!
    private var summonsChar:CaBotNotifyChar!
    private var destinationChar:CaBotNotifyChar!
    private var findPersonChar:CaBotNotifyChar!
    private var naviChar:CaBotNaviChar!
    private var heartbeatChar:CaBotNotifyChar!
    private var speechChar:CaBotSpeechChar!
    private var manageChar:CaBotNotifyChar!
    private var characteristics:[CBCharacteristic] = []
    private var chars:[CaBotChar] = []
    private let peripheralRestoreKey:String = UUID().uuidString
    enum add_state:Int{
        case none = 0
        case adding = 1
        case added = 2
    }
    private var serviceAdded:add_state = .none
    private var contrialCount:Int = CONTRIAL_MAX

    func requestAuthorized() -> Bool{
        return CBCentralManager.authorization == .allowedAlways
    }
    func prepareIfAuthorized(){
        if (self.requestAuthorized()) {
            self.prepare()
        }
    }
    func startIfAuthorized() {
        if (self.requestAuthorized()) {
            self.start();
        }
    }

    func prepare() {
        if self.peripheralManager != nil {return}
        let peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                     options: [CBPeripheralManagerOptionShowPowerAlertKey: true,
                                                               CBPeripheralManagerOptionRestoreIdentifierKey: peripheralRestoreKey])

        self.chars.append(CaBotVersionChar(service: self, handle: 0x0000, version: CaBotService.CABOT_BLE_VERSION))
        self.manageChar = CaBotNotifyChar(service: self, handle: 0x0001)
        self.chars.append(self.manageChar)

        self.chars.append(CaBotDeviceStatusChar(service: self, handle: 0x0002))
        self.chars.append(CaBotSystemStatusChar(service: self, handle: 0x0003))
        self.chars.append(CabotBatteryStatusChar(service: self, handle: 0x0004))
        self.logChar = CaBotNotifyChar(service: self, handle:0x0005)
        self.chars.append(self.logChar)

        self.summonsChar = CaBotNotifyChar(service: self, handle:0x00010)
        self.chars.append(self.summonsChar)

        self.destinationChar = CaBotNotifyChar(service: self, handle:0x0011)
        self.chars.append(self.destinationChar)

        self.chars.append(CaBotFindPersonReadyChar(service: self, handle:0x0020))
        self.findPersonChar = CaBotNotifyChar(service: self, handle:0x0021)
        self.chars.append(self.findPersonChar)

        self.speechChar = CaBotSpeechChar(service: self, handle:0x0030)
        self.chars.append(self.speechChar)

        self.naviChar = CaBotNaviChar(service: self, handle:0x0040)
        self.chars.append(self.naviChar)

        self.chars.append(CaBotWebContentChar(service: self, handle:0x0050))

        self.chars.append(CaBotSoundEffectChar(service: self, handle:0x0060))

        self.heartbeatChar = CaBotNotifyChar(service: self, handle:0x9999)
        self.chars.append(self.heartbeatChar)
        self.peripheralManager = peripheralManager
    }
    func start(){
        self.prepare()
        self.addService()
    }
    func stop(){
        self.stopAdvertising()
        self.removeService()
    }

    var heartBeatTimer:Timer? = nil
    
    internal func startHeartBeat() {
        self.heartBeatTimer?.invalidate()
        self.heartBeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            DispatchQueue.main.async {
                //NSLog("heartbeat")
                if self.checkAdvertisement() == false {
                    NSLog("disconnected from the server")
                    timer.invalidate()
                    self.contrialCount = 0
                }

                if (self.heartbeatChar.notify(value: "1", retry: 0)) {
                    self.contrialCount = CaBotService.CONTRIAL_MAX
                    NSLog("heartBeat success")
                } else {
                    self.contrialCount = self.contrialCount - 1
                    NSLog("heartBeat failure    ")
                }
                if(self.contrialCount > 0){
                    self.delegate?.caBot(service: self, centralConnected: true)
                }else{
                    self.delegate?.caBot(service: self, centralConnected: false)
                    self.delegate?.caBot(service: self, faceappConnected: false)
                }
            }
        }
    }

    // MARK: public functions
    
    public func activityLog(category: String = "", text: String = "", memo: String = "") -> Bool{
        let json: Dictionary<String, String> = [
            "category": category,
            "text": text,
            "memo": memo
        ]
        do {
            NSLog("activityLog \(category), \(text), \(memo)")
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let result = logChar.notify(data: data)
            if result == false {
                NSLog("FAIL activityLog \(category), \(text), \(memo)")
            }
        } catch {
            NSLog("activityLog \(category), \(text), \(memo)")
        }
        return false
    }

    public func send(destination: String) -> Bool {
        NSLog("destination \(destination)")
        return (self.destinationChar.notify(value: destination))
    }

    public func summon(destination: String) -> Bool {
        NSLog("summons \(destination)")
        return (self.summonsChar.notify(value: destination))
    }
    
    public func find(person: String) -> Bool {
        NSLog("person \(person)")
        return (self.findPersonChar.notify(value: "\(person);100000"))
    }

    public func manage(command: CaBotManageCommand) -> Bool {
        NSLog("manage \(command.rawValue)")
        return (self.manageChar.notify(value: command.rawValue))
    }

    public func startAdvertising() {
        guard let peripheralManager = self.peripheralManager else {
            return
        }
        let localName = "CaBot" + (self.teamID != nil ? "-" + self.teamID! : "")
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: localName,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: self.uuid.uuidString)]
        ]
        if (!peripheralManager.isAdvertising) {
            peripheralManager.startAdvertising(advertisementData)
            NSLog("Start advertising \(localName)")
        }
    }

    public func stopAdvertising() {
        guard let peripheralManager = self.peripheralManager else {
            return
        }
        if (peripheralManager.isAdvertising) {
            peripheralManager.stopAdvertising();
            NSLog("Stop advertising")
        }
    }

    public func notifyDeviceStatus(status: DeviceStatus) {
        guard let delegate = self.delegate else {
            return
        }
        delegate.cabot(service: self, deviceStatus: status)
    }

    public func notifySystemStatus(status: SystemStatus) {
        guard let delegate = self.delegate else {
            return
        }
        delegate.cabot(service: self, systemStatus: status)
    }

    public func notifyBatteryStatus(status: BatteryStatus) {
        guard let delegate = self.delegate else {
            return
        }
        delegate.cabot(service: self, batteryStatus: status)
    }

    // MARK: private functions

    internal func add(characteristic:CBCharacteristic) {
        self.characteristics.append(characteristic)
    }
    private let add_service_lock = NSLock()
    private func addService()
    {
        defer{self.add_service_lock.unlock()}
        self.add_service_lock.lock()
        guard let peripheralManager = self.peripheralManager else {return}
        if self.serviceAdded == .added {
            startAdvertising()
            return
        }
        if self.cbpm_state != .poweredOn{
            self.need_add_service = true
        }else{
            if self.serviceAdded != .adding{
                let service:CBMutableService = CBMutableService(type: self.uuid, primary: true)
                service.characteristics = self.characteristics
                
                NSLog("adding a service")
                peripheralManager.add(service)
                self.serviceAdded = .adding
            }
        }
    }
    private func removeService(){
        guard let peripheralManager = self.peripheralManager else {return}
        peripheralManager.removeAllServices()
        self.serviceAdded = .none
    }
    private var checkCount:Int = 0
    private func checkAdvertisement() -> Bool
    {
        if (self.heartbeatChar.characteristic_read.subscribedCentrals?.count ?? 0 > 0) {
            self.checkCount = 0
            self.stopAdvertising()
            return true
        } else {
            self.checkCount += 1
            if self.checkCount > 15 {
                self.stopAdvertising()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.startAdvertising()
                }
                self.checkCount = 0
            } else {
                self.startAdvertising()
            }
        }
        return false
    }

    // MARK: CBPeripheralManagerDelegate
    private var need_add_service:Bool = false
    private var cbpm_state:CBManagerState = .unknown

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        NSLog("state: \(peripheral.state.rawValue)")

        self.cbpm_state = peripheral.state
        if self.need_add_service, peripheral.state == .poweredOn {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                self.addService();
            }
        }

        guard let delegate = self.delegate else { return }
        delegate.cabot(service: self, bluetoothStateUpdated: peripheral.state)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            NSLog("error: \(error)")
            return
        }
        
        NSLog("service added")
        for char in service.characteristics! {
            NSLog("\(char.uuid)")
        }
        self.serviceAdded = .added
        self.startAdvertising();
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
        if let error = error {
            NSLog("Failed… error: \(error)")
            return
        }
        NSLog("Start advertising succeeded!")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        NSLog("didReceiveRead \(request)")
        for char in self.chars {
            if char.canHandle(readRequest: request) {
                break
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        NSLog("didReceiveWrite \(requests)")
        guard let peripheralManager = self.peripheralManager else {return}
        for request in requests
        {
            for char in self.chars {
                if char.canHandle(writeRequest: request) {
                    break
                }
            }
            peripheralManager.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        NSLog("subscribed centrals: \(central)")

        if characteristic.uuid == self.heartbeatChar.characteristic_read.uuid {
            self.startHeartBeat()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        NSLog("peripheral willRestore")
        if let _ = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBCentral] {
            NSLog("restored")
        }
    }

}

class CaBotChar: NSObject {
    let service:CaBotService
    
    init(service: CaBotService) {
        self.service = service
    }
    
    func canHandle(readRequest: CBATTRequest) -> Bool {
        return false
    }
    
    func canHandle(writeRequest: CBATTRequest) -> Bool {
        return false
    }
}

class CaBotNotifyChar: CaBotChar {
    let characteristic_read: CBMutableCharacteristic
    
    init(service:CaBotService, handle:Int) {
        
        self.characteristic_read = CBMutableCharacteristic(
            type: service.generateUUID(handle: handle),
            properties: [.indicate],
            value: nil,
            permissions: [.readable])
        
        service.add(characteristic: self.characteristic_read)
        
        super.init(service: service)
    }
    
    func notify(data:Data, retry:Int = 10) -> Bool {
        guard let peripheralManager = self.service.peripheralManager else {return false}
        if self.characteristic_read.subscribedCentrals?.count == 0 {
            return false
        }

        NSLog("notify to "+self.characteristic_read.uuid.uuidString)
        if peripheralManager.updateValue(data, for: self.characteristic_read, onSubscribedCentrals: nil) == false {
            if retry == 0 {
                return false
            }
            NSLog("FAIL(\(retry)) notify to \(self.characteristic_read.uuid.uuidString)")
            DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                self.notify(data: data, retry: retry-1)
            }
        }
        return true
    }
    
    func notify(value:String, retry:Int = 10) -> Bool {
        let data = Data(value.utf8)
        return self.notify(data: data, retry: retry)
    }
}

class CaBotStoreChar: CaBotChar {
    let configKey:String
    let characteristic_read: CBMutableCharacteristic
    let characteristic_write: CBMutableCharacteristic
    
    init(service:CaBotService, handles:[Int], configKey:String){
        
        self.characteristic_read = CBMutableCharacteristic(
            type: service.generateUUID(handle: handles[0]),
            properties: [.notify],
            value: nil,
            permissions: [])
        
        self.characteristic_write = CBMutableCharacteristic(
            type: service.generateUUID(handle: handles[1]),
            properties: [.write],
            value: nil,
            permissions: [.writeable])
        
        service.add(characteristic: self.characteristic_read)
        service.add(characteristic: self.characteristic_write)
        
        self.configKey = configKey
        super.init(service: service)
        
        UserDefaults.standard.addObserver(self, forKeyPath: configKey, options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let peripheralManager = self.service.peripheralManager else {return}
        if let data = self.valueData {
            peripheralManager.updateValue(data, for: self.characteristic_read, onSubscribedCentrals: nil)
        }
    }
    
    var value: Any? {
        get {
            return UserDefaults.standard.value(forKey: configKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: configKey)
        }
    }
    
    var valueData: Data? {
        get {
            if let value = self.value{
                return Data("\(value)".utf8)
            }
            return nil
        }
        set {
            if let value = newValue {
                if let str = String(data: value, encoding: .utf8) {
                    if let f = Float(str) {
                        self.value = f
                    }
                    else {
                        self.value = str
                    }
                }
            }
        }
    }
    
    override func canHandle(readRequest: CBATTRequest) -> Bool {
        guard let peripheralManager = self.service.peripheralManager else {return false}
        if readRequest.characteristic.uuid.isEqual(self.characteristic_read.uuid) {
            readRequest.value = self.valueData
            peripheralManager.respond(
                to: readRequest,
               withResult: .success)
            return true
        }
        return false
    }
    
    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic_write.uuid) {
            self.valueData = writeRequest.value
            return true
        }
        return false
    }
}

class CaBotQueryChar: CaBotChar {
    let characteristic_read: CBMutableCharacteristic
    let characteristic_write: CBMutableCharacteristic
    let operation: (String)->(String)
    
    init(service:CaBotService, handles:[Int], operation: @escaping (_ query:String)->(String)){
        
        self.characteristic_read = CBMutableCharacteristic(
            type: service.generateUUID(handle: handles[0]),
            properties: [.notify],
            value: nil,
            permissions: [])
        
        self.characteristic_write = CBMutableCharacteristic(
            type: service.generateUUID(handle: handles[1]),
            properties: [.write],
            value: nil,
            permissions: [.writeable])
        
        self.operation = operation
        
        service.add(characteristic: self.characteristic_read)
        service.add(characteristic: self.characteristic_write)
        
        super.init(service: service)
    }
    
    private func timeElapsedInSecondsWhenRunningCode(operation: ()->()) -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()
        operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return Double(timeElapsed)
    }
    
    private func request(_ request:CBATTRequest) {
        guard let val = request.value else {
            return
        }
        guard let query = String(data: val, encoding: .utf8) else {
            return
        }
        self.request(query, mtu: request.central.maximumUpdateValueLength)
    }
    
    public func request(_ query:String, mtu:Int) {
        let queue = DispatchQueue(label: "Wiring-queue")
        queue.async {
            guard let peripheralManager = self.service.peripheralManager else {return}
            var ret = self.operation(query)
            let dataLength = ret.count
        
            let duration = self.timeElapsedInSecondsWhenRunningCode {
                while ret.count > 0 {
                    let temp = ret.prefix(mtu)
                    if peripheralManager.updateValue(Data(temp.utf8), for: self.characteristic_read, onSubscribedCentrals: nil) {
                        ret = String(ret.suffix(max(0, ret.count-mtu)))
                    }
                    usleep(1000)
                }
            }
            NSLog(String(format:"%.2f kbytes in %.2f secs = %.2f kbps", Double(dataLength) / 1024.0, duration, Double(dataLength)/duration*8/1024))
        }
    }
    
    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic_write.uuid) {
            self.request(writeRequest)
            //self.service.peripheralManager.respond(
            //    to: writeRequest,
            //    withResult: .success)
            return true
        }
        return false
    }
}

class CaBotBufferedWriteChar: CaBotChar {
    let uuid:CBUUID
    let characteristic: CBMutableCharacteristic
    var buffer: Data = Data()
    var dataSize: Int = 0
    var packetOffset: Int = 0
    var dataReceived: Int = 0

    init(service: CaBotService, handle: Int) {
        self.uuid = service.generateUUID(handle: handle)
        self.characteristic = CBMutableCharacteristic(
            type: self.uuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable])
        service.add(characteristic: self.characteristic)
        super.init(service: service)
    }

    func handleData(_ data:Data) {
        preconditionFailure("handleRequest needs to be implemented")
    }

    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic.uuid) {
            guard let temp = writeRequest.value else {
                return false
            }
            let data = Data(temp)
            guard data.count > 0 else {
                return false
            }


            NSLog("canHandle uuid=\(self.characteristic.uuid) len=\(data.count) dataSize=\(dataSize) dataReceived=\(self.dataReceived) offset=\(writeRequest.offset)")
            if writeRequest.offset == 0 {
                guard data.count >= 4  else {
                    return false
                }
                self.dataSize = Int(data[0]) * 256 + Int(data[1])
                self.packetOffset = Int(data[2]) * 256 + Int(data[3])
                NSLog("canHandle uuid=\(self.characteristic.uuid) dataSize=\(self.dataSize) packetOffset=\(self.packetOffset)")
                if self.packetOffset == 0 {
                    self.dataReceived = 0
                }
                if self.buffer.count == 0 {
                    self.buffer = Data(repeating: 0, count: self.dataSize)
                }
                for i in 4..<data.count {
                    self.buffer[i + self.packetOffset - 4] = data[i]
                    self.dataReceived += 1
                }
            } else {
                for i in 0..<data.count {
                    self.buffer[i + self.packetOffset - 4 + writeRequest.offset] = data[i]
                    self.dataReceived += 1
                }
            }

            if self.dataReceived == self.dataSize {
                NSLog("canHandle uuid=\(self.characteristic.uuid) dataSize=\(dataSize) bufferSize=\(self.buffer.count)")
                if buffer.isGzipped {
                    do {
                        let decompressedData = try buffer.gunzipped()
                        self.handleData(decompressedData)
                    } catch {
                        NSLog("gunzip error")
                    }
                } else {
                    self.handleData(buffer)
                }
                buffer.removeAll()
            }

            return true
        }
        return false
    }
}

class CaBotTextWriteChar: CaBotBufferedWriteChar {
    override func handleData(_ data:Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        self.handleText(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func handleText(_ text:String) {
        preconditionFailure("handleText needs to be implemented")
    }
}

class CaBotVersionChar: CaBotTextWriteChar {
    let version:String
    init(service:CaBotService, handle:Int, version:String) {
        self.version = version
        super.init(service: service, handle: handle)
    }

    override func handleText(_ text: String) {
        self.service.delegate?.caBot(service:self.service, versionMatched:text == version, with:text)
    }
}

class CaBotFindPersonReadyChar: CaBotTextWriteChar {

    override func handleText(_ text: String) {
        DispatchQueue.main.async {
            // Backpack is ready
            let ready:Bool = (text == "True") ? true : false

            self.service.faceappReady = ready
            self.service.delegate?.caBot(service: self.service, faceappConnected: ready)

            NSLog("Back pack ready:", text, ready)
        }
    }

}

class CaBotSpeechChar: CaBotTextWriteChar {
    override func handleText(_ text: String) {
        DispatchQueue.main.async {
            let tts = self.service.tts

            for line in text.split(separator: "\n") {
                var force: Bool = false
                if line == "__force_stop__" {
                    tts.speak("") {
                    }
                    force = true
                } else {
                    if !tts.isSpeaking {
                        _ = self.service.activityLog(category: "ble speech request speaking", text: String(line), memo: "force=\(force)")
                        tts.speak(String(line)) { code in
                            if code > 0 {
                                _ = self.service.activityLog(category: "ble speech request completed", text: String(line), memo: "force=\(force),return_code=\(code)")
                            } else {
                                _ = self.service.activityLog(category: "ble speech request canceled", text: String(line), memo: "force=\(force),return_code=\(code)")
                            }
                        }
                    } else {
                        NSLog("TTS is busy and skip speaking: \(line)")
                        _ = self.service.activityLog(category: "ble speech request skipped", text: String(line), memo: "TTS is busy")
                    }
                }
            }
        }
    }
}

class CaBotNaviChar: CaBotTextWriteChar {
    override func handleText(_ text: String) {
        DispatchQueue.main.async {
            if let note = NavigationNotification(rawValue: text) {
                self.service.delegate?.cabot(service: self.service, notification: note)
            } else {
                NSLog("Unknown navigation notification type %@", text)
            }
        }
    }
}


class CaBotWebContentChar: CaBotTextWriteChar {
    override func handleText(_ text: String) {
        DispatchQueue.main.async {
            guard let url = URL(string: text) else {
                return
            }
            self.service.delegate?.cabot(service: self.service, openRequest: url)
        }
    }
}


class CaBotSoundEffectChar: CaBotTextWriteChar {
    override func handleText(_ text: String) {
        DispatchQueue.main.async {
            self.service.delegate?.cabot(service: self.service, soundRequest: text)
        }
    }
}

class CaBotDeviceStatusChar: CaBotBufferedWriteChar {
    override func handleData(_ data: Data) {
        do {
            let status = try JSONDecoder().decode(DeviceStatus.self, from: data)
            DispatchQueue.main.async {
                self.service.notifyDeviceStatus(status: status)
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            print(text)
        } catch {
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            print(text)
            NSLog(error.localizedDescription)
        }
    }
}

class CaBotSystemStatusChar: CaBotBufferedWriteChar {
    override func handleData(_ data: Data) {
        do {
            let status = try JSONDecoder().decode(SystemStatus.self, from: data)
            DispatchQueue.main.async {
                self.service.notifySystemStatus(status: status)
            }
        } catch {
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            print(text)
            NSLog(error.localizedDescription)
        }
    }
}

class CabotBatteryStatusChar: CaBotBufferedWriteChar {
    override func handleData(_ data: Data) {
        do {
            let status = try JSONDecoder().decode(BatteryStatus.self, from: data)
            DispatchQueue.main.async {
                self.service.notifyBatteryStatus(status: status)
            }
        } catch {
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            print(text)
            NSLog(error.localizedDescription)
        }
    }
}
