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
import CoreBluetooth
import HLPDialog

enum NavigationNotification:String {
    case next
    case arrived
}

protocol CaBotServiceDelegate {
    func caBot(service:CaBotService, centralConnected:Bool)
    func caBot(service:CaBotService, faceappConnected:Bool)
    func cabot(service:CaBotService, bluetoothStateUpdated: CBManagerState)
    func cabot(service:CaBotService, openRequest:URL)
    func cabot(service:CaBotService, notification:NavigationNotification)
}

class CaBotService: NSObject, CBPeripheralManagerDelegate {
    static let UUID_FORMAT = "35CE%04X-5E89-4C0D-A3F6-8A6A507C1BF1"
    static let CABOT_SPEED_CONFIG = "cabot_speed"
    static let SPEECH_SPEED_CONFIG = "speech_speed"

    func generateUUID(handle:Int) -> CBUUID {
        return CBUUID(string: String(format:CaBotService.UUID_FORMAT, handle))
    }
    

    public var delegate:CaBotServiceDelegate?
    public var teamID:String? = nil
    public var faceappReady:Bool = false
    public var peripheralManager:CBPeripheralManager!
    public var tts:CaBotTTS = CaBotTTS(voice: nil)

    private let uuid = CBUUID(string: String(format:UUID_FORMAT, 0x0000))
    private var destinationChar:CaBotNotifyChar!
    private var findPersonChar:CaBotNotifyChar!
    private var naviChar:CaBotNaviChar!
    private var heartbeatChar:CaBotNotifyChar!
    private var speechChar:CaBotSpeechChar!
    private var characteristics:[CBCharacteristic] = []
    private var chars:[CaBotChar] = []
    private let peripheralRestoreKey:String = UUID().uuidString

    override init(){
        super.init()
        if (CBCentralManager.authorization == .allowedAlways) {
            start(); 
        }
    }

    func start() {
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                     options: [CBPeripheralManagerOptionShowPowerAlertKey: true,
                                                               CBPeripheralManagerOptionRestoreIdentifierKey: peripheralRestoreKey])

        self.chars.append(CaBotStoreChar(service: self, handles:[0x0001, 0x0002], configKey:CaBotService.CABOT_SPEED_CONFIG))
        self.chars.append(CaBotStoreChar(service: self, handles:[0x0003, 0x0004], configKey:CaBotService.SPEECH_SPEED_CONFIG))

        self.destinationChar = CaBotNotifyChar(service: self, handle:0x0010)
        self.chars.append(self.destinationChar)

        self.chars.append(CaBotFindPersonReadyChar(service: self, handle:0x0011))

        self.findPersonChar = CaBotNotifyChar(service: self, handle:0x0012)
        self.chars.append(self.findPersonChar)

        self.chars.append(CaBotQueryChar(service: self, handles:[0x0100, 0x0101]) { query in
            return ""
        })
        self.speechChar = CaBotSpeechChar(service: self, handle:0x0200)
        self.chars.append(self.speechChar)

        self.naviChar = CaBotNaviChar(service: self, handle:0x0300)
        self.chars.append(self.naviChar)

        self.chars.append(CaBotWebContentChar(service: self, handle:0x0400))

        self.heartbeatChar = CaBotNotifyChar(service: self, handle:0x9999)
        //self.heartbeatChar = CaBotHeartBeatChar(service: self, handle:0x9999)
        self.chars.append(self.heartbeatChar)
    }

    var heartBeatTimer:Timer? = nil
    
    internal func startHeartBeat() {
        self.heartBeatTimer?.invalidate()
        self.heartBeatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            DispatchQueue.main.async {
                //NSLog("heartbeat")
                self.checkAdvertisement();

                if (self.heartbeatChar.notify(value: "1")) {
                    self.delegate?.caBot(service: self, centralConnected: true)
                } else {
                    self.delegate?.caBot(service: self, centralConnected: false)
                    self.delegate?.caBot(service: self, faceappConnected: false)
                }
            }
        }
    }

    public func setVoice(_ voice: AVSpeechSynthesisVoice) {
        tts.voice = voice
    }
    
    public func send(destination: String) -> Bool {
        NSLog("destination \(destination)")
        return (self.destinationChar.notify(value: destination))
    }
    
    public func find(person: String) -> Bool {
        NSLog("person \(person)")
        return (self.findPersonChar.notify(value: "\(person);100000"))
    }
    
    internal func add(characteristic:CBCharacteristic) {
        self.characteristics.append(characteristic)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        NSLog("state: \(peripheral.state.rawValue)")
        
        if peripheral.state == .poweredOn {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                self.addService();
            }
        }

        guard let delegate = self.delegate else { return }
        delegate.cabot(service: self, bluetoothStateUpdated: peripheral.state)
    }
    
    private func addService()
    {
        let service:CBMutableService = CBMutableService(type: self.uuid, primary: true)
        service.characteristics = self.characteristics
        
        NSLog("adding a service")
        peripheralManager.add(service)
    }
    
    private func checkAdvertisement()
    {
        if (self.heartbeatChar.characteristic_read.subscribedCentrals?.count ?? 0 > 0) {
            stopAdvertising()
        } else {
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            NSLog("error: \(error)")
            return
        }
        
        NSLog("service added: \(service)")
        self.startAdvertising();
    }

    func startAdvertising() {
        let localName = "CaBot" + (self.teamID != nil ? "-" + self.teamID! : "")
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: localName,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: self.uuid.uuidString)]
        ]
        if (!self.peripheralManager.isAdvertising) {
            peripheralManager.startAdvertising(advertisementData)
            NSLog("Start advertising \(localName)")
        }
    }

    func stopAdvertising() {
        if (self.peripheralManager.isAdvertising) {
            self.peripheralManager.stopAdvertising();
            NSLog("Stop advertising")
        }
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
        //NSLog("didReceiveWrite \(requests)")
        for request in requests
        {
            for char in self.chars {
                if char.canHandle(writeRequest: request) {
                    break
                }
            }
        }
        peripheralManager.respond(to: requests[0], withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        NSLog("subscribed centrals: \(central)")

        self.startHeartBeat()
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
            properties: [.notify],
            value: nil,
            permissions: [])
        
        service.add(characteristic: self.characteristic_read)
        
        super.init(service: service)
    }
    
    func notify(value:String, retry:Int = 10) -> Bool {
        let data = Data(value.utf8)

        if self.characteristic_read.subscribedCentrals?.count == 0 {
            return false
        }

        NSLog("notify to "+self.characteristic_read.uuid.uuidString)
        return self.service.peripheralManager.updateValue(data, for: self.characteristic_read, onSubscribedCentrals: nil)
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
        if let data = self.valueData {
            self.service.peripheralManager.updateValue(data, for: self.characteristic_read, onSubscribedCentrals: nil)
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
        if readRequest.characteristic.uuid.isEqual(self.characteristic_read.uuid) {
            readRequest.value = self.valueData
            self.service.peripheralManager.respond(
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
            var ret = self.operation(query)
            let dataLength = ret.count
        
            let duration = self.timeElapsedInSecondsWhenRunningCode {
                while ret.count > 0 {
                    let temp = ret.prefix(mtu)
                    if self.service.peripheralManager.updateValue(Data(temp.utf8), for: self.characteristic_read, onSubscribedCentrals: nil) {
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
            self.service.peripheralManager.respond(
                to: writeRequest,
                withResult: .success)
            return true
        }
        return false
    }
}

class CaBotFindPersonReadyChar: CaBotChar {
    let uuid:CBUUID
    let characteristic: CBMutableCharacteristic
    
    init(service: CaBotService,
         handle:Int) {
        self.uuid = service.generateUUID(handle: handle)
        
        self.characteristic = CBMutableCharacteristic(
            type: self.uuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable])
        
        service.add(characteristic: self.characteristic)
        
        super.init(service: service)
    }
    
    private func request(_ request:CBATTRequest) {
        DispatchQueue.main.async {
            guard let data = request.value else {
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            // Backpack is ready
            let ready:Bool = (text == "True") ? true : false
            
            self.service.faceappReady = ready
            self.service.delegate?.caBot(service: self.service, faceappConnected: ready)
            
            NSLog("Back pack ready:", text, ready)
        }
    }
    
    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic.uuid) {
            self.request(writeRequest)
            self.service.peripheralManager.respond(
                to: writeRequest,
                withResult: .success)
            return true
        }
        return false
    }
}

class CaBotSpeechChar: CaBotChar {
    let uuid:CBUUID
    let characteristic: CBMutableCharacteristic


    init(service: CaBotService,
         handle:Int) {
        self.uuid = service.generateUUID(handle: handle)
        
        self.characteristic = CBMutableCharacteristic(
            type: self.uuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable])
        
        service.add(characteristic: self.characteristic)
        
        super.init(service: service)
    }

    private func request(_ request:CBATTRequest) {
        DispatchQueue.main.async {
            guard let data = request.value else {
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            let tts = self.service.tts

            for line in text.split(separator: "\n") {
                if line == "__force_stop__" {
                    tts.speak("") {
                    }
                } else {
                    tts.speak(String(line)) {
                    }
                }
            }
        }
    }
    
    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic.uuid) {
            self.request(writeRequest)
            self.service.peripheralManager.respond(
                to: writeRequest,
                withResult: .success)
            return true
        }
        return false
    }
}

class CaBotNaviChar: CaBotChar {
    let uuid:CBUUID
    let characteristic: CBMutableCharacteristic

    init(service: CaBotService,
         handle:Int) {
        self.uuid = service.generateUUID(handle: handle)

        self.characteristic = CBMutableCharacteristic(
            type: self.uuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable])

        service.add(characteristic: self.characteristic)

        super.init(service: service)
    }

    private func request(_ request:CBATTRequest) {
        DispatchQueue.main.async {
            guard let data = request.value else {
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }
            if let note = NavigationNotification(rawValue: text) {
                self.service.delegate?.cabot(service: self.service, notification: note)
            } else {
                NSLog("Unknown navigation notification type %@", text)
            }
        }
    }

    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic.uuid) {
            self.request(writeRequest)
            self.service.peripheralManager.respond(
                to: writeRequest,
                withResult: .success)
            return true
        }
        return false
    }
}


class CaBotWebContentChar: CaBotChar {
    let uuid:CBUUID
    let characteristic: CBMutableCharacteristic

    init(service: CaBotService,
         handle:Int) {
        self.uuid = service.generateUUID(handle: handle)

        self.characteristic = CBMutableCharacteristic(
            type: self.uuid,
            properties: [.write],
            value: nil,
            permissions: [.writeable])

        service.add(characteristic: self.characteristic)

        super.init(service: service)
    }

    private func request(_ request:CBATTRequest) {
        DispatchQueue.main.async {
            guard let data = request.value else {
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return
            }

            self.service.delegate?.cabot(service: self.service, openRequest: URL(string: text)!)
        }
    }

    override func canHandle(writeRequest: CBATTRequest) -> Bool {
        if writeRequest.characteristic.uuid.isEqual(self.characteristic.uuid) {
            self.request(writeRequest)
            self.service.peripheralManager.respond(
                to: writeRequest,
                withResult: .success)
            return true
        }
        return false
    }
}

