/*******************************************************************************
 * Copyright (c) 2019  Carnegie Mellon University
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

//
//  CaBotService.swift
//  CaBot
//
//  Created by Daisuke Sato on 2019/05/13.
//  Copyright © 2019 Daisuke Sato. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol CaBotServiceDelegate {
    func caBot(service:CaBotService, centralConnected:Bool)
}
class settings{
    
    public static func _get_default_string(_ forKey:String, defval:String? = nil) -> String?{
        if let ret = UserDefaults.standard.string(forKey: forKey), !ret.isEmpty{
            return ret
        }else{
            return defval
        }
    }
}


class CaBotService: NSObject, CBPeripheralManagerDelegate {
    static let UUID_FORMAT = "35CE%04X-5E89-4C0D-A3F6-8A6A507C1BF1"
    static let CABOT_SPEED_CONFIG = "cabot_speed"
    static let SPEECH_SPEED_CONFIG = "speech_speed"
    
    func generateUUID(handle:Int) -> CBUUID {
        return CBUUID(string: String(format:CaBotService.UUID_FORMAT, handle))
    }
    
    let uuid = CBUUID(string: String(format:UUID_FORMAT, 0x0000))
    var destinationChar:CaBotNotifyChar!
    var hearbeatChar:CaBotNotifyChar!
    var peripheralManager:CBPeripheralManager!
    var characteristics:[CBCharacteristic] = []
    var chars:[CaBotChar] = []
    var delegate:CaBotServiceDelegate?

    
    override init(){
        super.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil,
                                                     options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        
        self.chars.append(CaBotStoreChar(service: self, handles:[0x0001, 0x0002], configKey:CaBotService.CABOT_SPEED_CONFIG))
        self.chars.append(CaBotStoreChar(service: self, handles:[0x0003, 0x0004], configKey:CaBotService.SPEECH_SPEED_CONFIG))
        
        self.destinationChar = CaBotNotifyChar(service: self, handle:0x0010)
        self.chars.append(self.destinationChar)
        
        self.chars.append(CaBotQueryChar(service: self, handles:[0x0100, 0x0101]) { query in
            return ""
        })
        self.chars.append(CaBotSpeechChar(service: self, handle:0x0200))
        
        self.hearbeatChar = CaBotNotifyChar(service: self, handle:0x9999)
        self.chars.append(self.hearbeatChar)
        
        self.startHeartBeat()
    }
    
    internal func startHeartBeat() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { (timer) in
            DispatchQueue.main.async {
                print("heartbeat")
                if (!self.hearbeatChar.notify(value: "1")) {
                    self.delegate?.caBot(service: self, centralConnected: false)
                } else {
                    self.delegate?.caBot(service: self, centralConnected: true)
                }
            }
        }
    }
    
    public func send(destination: String) -> Bool {
        print("destination \(destination)")
        return (self.destinationChar.notify(value: destination))
    }
    
    internal func add(characteristic:CBCharacteristic) {
        self.characteristics.append(characteristic)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        print("state: \(peripheral.state.rawValue)")
        
        if peripheral.state == .poweredOn {
            DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                self.addService();
            }
        }
    }
    
    private func addService()
    {
        let service:CBMutableService = CBMutableService(type: self.uuid, primary: true)
        service.characteristics = self.characteristics
        
        print("adding a service")
        peripheralManager.add(service)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("error: \(error)")
            return
        }
        
        print("service added: \(service)")
        let teamid:String? = settings._get_default_string("team_id")
        let advertisementData = [CBAdvertisementDataLocalNameKey: "CaBot" + (teamid != nil ? "-" + teamid! : "")]
        peripheralManager.startAdvertising(advertisementData)
        
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
        if let error = error {
            print("Failed… error: \(error)")
            return
        }
        print("Succeeded!)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("didReceiveRead \(request)")
        for char in self.chars {
            if char.canHandle(readRequest: request) {
                break
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("didReceiveWrite \(requests)")
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
        print("subscribed centrals: \(central)")
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
        var ret = false
        var count = 0
        
        if self.characteristic_read.subscribedCentrals?.count == 0 {
            return false
        }

        //while (!ret && count < retry) {
        print("notify to "+self.characteristic_read.uuid.uuidString)
            ret = self.service.peripheralManager.updateValue(data, for: self.characteristic_read, onSubscribedCentrals: nil)
            count += 1
        //}
        return ret
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
            print(String(format:"%.2f kbytes in %.2f secs = %.2f kbps", Double(dataLength) / 1024.0, duration, Double(dataLength)/duration*8/1024))
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
            guard let tts = NavDeviceTTS.shared() else {
                return
            }
                
            for line in text.split(separator: "\n") {
                if line == "__force_stop__" {
                    tts.speak("", withOptions: ["force": true], completionHandler: nil)
                } else {
                    tts.speak(String(line), withOptions: nil){
                        
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
