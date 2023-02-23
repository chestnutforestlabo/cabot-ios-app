/*******************************************************************************
 * Copyright (c) 2022  Carnegie Mellon University
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
import SocketIO


class CaBotService_tcp: NSObject, CabotTransportProtocol{
    fileprivate var tts:CaBotTTS
    fileprivate var socketURL:String!
    fileprivate var manager: SocketManager!
    fileprivate var socket: SocketIOClient!
    fileprivate let version:String = CaBotService.CABOT_BLE_VERSION + "_t"
    
    var delegate:CaBotServiceDelegate!
    
    init(with tts:CaBotTTS) {
        self.tts = tts
    }
    func set_addr(addr:String){
        self.socketURL = "ws://" + addr + "/cabot"
    }
    func emit(_ event: String, _ items: SocketData..., completion: (() -> ())? = nil)  {
        if let skt = self.socket, skt.status == .connected{
            self.socket.emit(event, items)
        }
    }
    func activityLog(category: String, text: String, memo: String) -> Bool {
        let json: Dictionary<String, String> = [
            "category": category,
            "text": text,
            "memo": memo
        ]
        do {
            NSLog("activityLog \(category), \(text), \(memo)")
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let text = String(data:data, encoding: .utf8)
            self.emit("log", text!)
            return true
        } catch {
            NSLog("activityLog \(category), \(text), \(memo)")
        }
        return false
    }
    
    func send(destination: String) -> Bool {
        NSLog("destination \(destination)")
        self.emit("destination", destination)
        return true
    }
    
    func summon(destination: String) -> Bool {
        NSLog("summons \(destination)")
        self.emit("summon", destination)
        return true
    }
    
    func find(person: String) -> Bool {
        //TODO no subscriber in the server?
        NSLog("person \(person)")
        self.emit("person", "\(person);100000")
        return true
    }
    
    func manage(command: CaBotManageCommand) -> Bool {
        NSLog("manage \(command.rawValue)")
        self.emit("manage_cabot", command.rawValue)//TODO emitwithack??
        return true
    }
    
    func startAdvertising() {
        //assuming nothing to do
    }
    
    func stopAdvertising() {
        //assuming nothing to do
    }
    
    func notifyDeviceStatus(status: DeviceStatus) {
        //assuming nothing to do
    }
    
    func notifySystemStatus(status: SystemStatus) {
        //assuming nothing to do
    }
    
    func notifyBatteryStatus(status: BatteryStatus) {
        //assuming nothing to do
    }
    
    func stop(){
        if let skt = self.socket{
            skt.disconnect()
        }
        if let mgr = self.manager{
            if let skt = self.socket{
                mgr.disconnectSocket(skt)
            }
            mgr.disconnect()
            self.manager = nil
        }
        self.socket = nil
    }
    func start() {

        if let socketUrl = self.socketURL as? String{
            manager = SocketManager(socketURL: URL(string: socketUrl)!, config: [.log(true), .compress, .reconnects(true), .reconnectWait(1), .reconnectAttempts(-1)])
            socket = manager.defaultSocket
            socket.on(clientEvent: .connect) {[weak self] data, ack in
                DispatchQueue.main.async {
                    self?.delegate.caBot(service: self!, centralConnected: true)
                }
                self?.socket.emit("req_version", true)
            }
            socket.on(clientEvent: .error){[weak self] data, ack in
                if let text = data[0] as? String{
                    /*self?.tts.speak(text){
                    }*/
                }
            }
            socket.on(clientEvent: .disconnect){[weak self] data, ack in
                DispatchQueue.main.async {
                    self?.delegate.caBot(service: self!, centralConnected: false)
                }
            }

            socket.on("device_status"){[weak self] dt, ack in
                if let text = dt[0] as? String, let data = String(text).data(using:.utf8){
                    do {
                        let status = try JSONDecoder().decode(DeviceStatus.self, from: data)
                        DispatchQueue.main.async {
                            self?.delegate.cabot(service: self!, deviceStatus: status)
                        }
                        guard let text = String(data: data, encoding: .utf8) else {
                            return
                        }
                        print(text)
                    } catch {
                        /*guard let text = String(data: data[0] as? Data, encoding: .utf8) else {
                            return
                        }
                        print(text)*/
                        NSLog(error.localizedDescription)
                    }
                }
                

            }
            socket.on("cabot_version"){[weak self] data, ack in
                if let text = data[0] as? String{
                    self?.delegate.caBot(service: self!, versionMatched: self!.version == text, with: text)
                }
            }
            socket.on("system_status"){[weak self] dt, ack in
                if let text = dt[0] as? String, let data = String(text).data(using:.utf8){
                    do {
                        let status = try JSONDecoder().decode(SystemStatus.self, from: data)
                        DispatchQueue.main.async {
                            self?.delegate.cabot(service: self!, systemStatus: status)
                        }
                    } catch {
                        print(text)
                        NSLog(error.localizedDescription)
                    }
                }
                
            }
            socket.on("battery_status"){[weak self] dt, ack in
                if let text = dt[0] as? String, let data = String(text).data(using:.utf8){
                    do {
                        let status = try JSONDecoder().decode(BatteryStatus.self, from: data)
                        DispatchQueue.main.async {
                            self?.delegate.cabot(service: self!, batteryStatus: status)
                        }
                    } catch {
                        print(text)
                        NSLog(error.localizedDescription)
                    }
                }
            }
            socket.on("speak"){[weak self] data, ack in
                if let text = data[0] as? String{
                    DispatchQueue.main.async {
                        if let tts = self?.tts{
                            for line in text.split(separator: "\n") {
                                var force: Bool = false
                                if line == "__force_stop__" {
                                    tts.speak("") {
                                    }
                                    force = true
                                } else {
                                    if !tts.isSpeaking {
                                        _ = self?.activityLog(category: "ble speech request speaking", text: String(line), memo: "force=\(force)")
                                        tts.speak(String(line)) { code in
                                            if code > 0 {
                                                _ = self?.activityLog(category: "ble speech request completed", text: String(line), memo: "force=\(force),return_code=\(code)")
                                            } else {
                                                _ = self?.activityLog(category: "ble speech request canceled", text: String(line), memo: "force=\(force),return_code=\(code)")
                                            }
                                        }
                                    } else {
                                        NSLog("TTS is busy and skip speaking: \(line)")
                                        _ = self?.activityLog(category: "ble speech request skipped", text: String(line), memo: "TTS is busy")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            socket.on("navigate"){[weak self] data, ack in
                if let text = data[0] as? String{
                    DispatchQueue.main.async {
                        if let note = NavigationNotification(rawValue: text) {
                            self?.delegate.cabot(service: self!, notification: note)
                        } else {
                            NSLog("Unknown navigation notification type %@", text)
                        }
                    }
                }
            }
            socket.on("content"){[weak self] data, ack in
                if let text = data[0] as? String{
                    DispatchQueue.main.async {
                        guard let url = URL(string: text) else {
                            return
                        }
                        self?.delegate.cabot(service: self!, openRequest: url)
                    }
                }
            }
            socket.on("sound"){[weak self] data, ack in
                if let text = data[0] as? String{
                    DispatchQueue.main.async {
                        self?.delegate.cabot(service: self!, soundRequest: text)
                    }
                }
            }
            socket.connect()
        }
    }
    
}
