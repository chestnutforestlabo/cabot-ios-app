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


class CaBotServiceTCP: NSObject, CaBotTransportProtocol{
    fileprivate var tts:CaBotTTS
    fileprivate var primaryAddr: String?
    fileprivate var secondaryAddr: String?
    fileprivate var port: String?
    fileprivate var manager: SocketManager?
    fileprivate var socket: SocketIOClient?
    fileprivate let version:String = CaBotServiceBLE.CABOT_BLE_VERSION

    private let actions = CaBotServiceActions.shared
    private var connected: Bool = true
    private var primaryIP = true
    private var connectTimer: Timer?

    var delegate:CaBotServiceDelegate?

    static func == (lhs: CaBotServiceTCP, rhs: CaBotServiceTCP) -> Bool {
        return lhs === rhs
    }

    init(with tts:CaBotTTS) {
        self.tts = tts
    }
    func emit(_ event: String, _ items: SocketData..., completion: (() -> ())? = nil)  {
        guard let socket = self.socket else { return }
        guard socket.status == .connected else { return }

        socket.emit(event, items)
    }

    func updateAddr(addr: String, port: String, secondary: Bool = false) {
        if secondary {
            guard self.secondaryAddr != addr else { return }
            self.secondaryAddr = addr
        } else {
            guard self.primaryAddr != addr else { return }
            self.primaryAddr = addr
        }
        self.port = port
    }

    // MARK: CaBotServiceProtocol

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
    
    func manage(command: CaBotManageCommand, param: String?) -> Bool {
        if let param = param {
            NSLog("manage \(command.rawValue)-\(param)")
            self.emit("manage_cabot", "\(command.rawValue)-\(param)")
            return true
        } else {
            NSLog("manage \(command.rawValue)")
            self.emit("manage_cabot", command.rawValue)
            return true
        }
    }

    func log_request(request: Dictionary<String, String>) -> Bool {
        NSLog("log_request \(request)")
        if let jsonString = try? JSONEncoder().encode(request) {
            self.emit("log_request", jsonString)
            return true
        }
        return false
    }


    public func isConnected() -> Bool {
        return self.connected
    }
    
    public func isSocket() -> Bool {
        self.socket != nil
    }

    // MARK: CaBotTransportProtocol

    func connectionType() -> ConnectionType {
        return .TCP
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
        let addr = getAddr()
        guard !addr.isEmpty else { return }
        guard let port = self.port else { return }

        let socketURL = "ws://" + addr + ":" + port + "/cabot"
        guard let url = URL(string: socketURL) else { return }

        let manager = SocketManager(socketURL: url, config: [.log(true), .compress, .reconnects(true), .reconnectWait(1), .reconnectAttempts(-1)])
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket
        socket.on(clientEvent: .connect) {[weak self] data, ack in
            guard let weakself = self else { return }
            guard let socket = weakself.socket else { return }
            guard let delegate = weakself.delegate else { return }
            DispatchQueue.main.async {
                weakself.connected = true
                delegate.caBot(service: weakself, centralConnected: weakself.connected)
            }
            socket.emit("req_version", true)
        }
        socket.on(clientEvent: .error){[weak self] data, ack in
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            DispatchQueue.main.async {
                weakself.connected = false
                weakself.stop()
                delegate.caBot(service: weakself, centralConnected: weakself.connected)
            }
        }
        socket.on(clientEvent: .disconnect){[weak self] data, ack in
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            DispatchQueue.main.async {
                weakself.connected = false
                weakself.changeURL()
                delegate.caBot(service: weakself, centralConnected: weakself.connected)
            }
        }
        socket.on("cabot_version"){[weak self] data, ack in
            guard let text = data[0] as? String else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            delegate.caBot(service: weakself, versionMatched: text == weakself.version, with: text)
        }
        socket.on("device_status"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let status = try JSONDecoder().decode(DeviceStatus.self, from: data)
                DispatchQueue.main.async {
                    delegate.cabot(service: weakself, deviceStatus: status)
                }
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.on("system_status"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let status = try JSONDecoder().decode(SystemStatus.self, from: data)
                DispatchQueue.main.async {
                    delegate.cabot(service: weakself, systemStatus: status)
                }
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.on("battery_status"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let status = try JSONDecoder().decode(BatteryStatus.self, from: data)
                DispatchQueue.main.async {
                    delegate.cabot(service: weakself, batteryStatus: status)
                }
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.on("speak"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let request = try JSONDecoder().decode(SpeakRequest.self, from: data)
                weakself.actions.handle(service: weakself, delegate: delegate, tts: weakself.tts, request: request)
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.on("navigate"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let request = try JSONDecoder().decode(NavigationEventRequest.self, from: data)
                weakself.actions.handle(service: weakself, delegate: delegate, request: request)
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.on("log_response"){[weak self] dt, ack in
            guard let text = dt[0] as? String else { return }
            guard let data = String(text).data(using:.utf8) else { return }
            guard let weakself = self else { return }
            guard let delegate = weakself.delegate else { return }
            do {
                let response = try JSONDecoder().decode(LogResponse.self, from: data)
                weakself.actions.handle(service: weakself, delegate: delegate, response: response)
            } catch {
                print(text)
                NSLog(error.localizedDescription)
            }
        }
        socket.connect()
    }

    private func changeURL() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0,
                                      execute: {
            if let primaryAddr = self.primaryAddr,
               !primaryAddr.isEmpty,
               let secondaryAddr = self.secondaryAddr,
               !secondaryAddr.isEmpty {
                self.primaryIP = !self.primaryIP
            }
            
            self.stop()
            self.start()
        })
    }

    private func getAddr() -> String {
        let primaryAddr = self.getPrimaryAddr()
        let secondaryAddr = self.getSecondaryAddr()

        let addr = self.primaryIP ? primaryAddr : secondaryAddr
        if !addr.isEmpty {
            return addr
        }

        if !primaryAddr.isEmpty {
            self.primaryIP = true
            return primaryAddr
        } else if !secondaryAddr.isEmpty {
            self.primaryIP = false
            return secondaryAddr
        }

        self.stop()
        return ""
    }

    private func getPrimaryAddr() -> String {
        if let primaryAddr = self.primaryAddr,
           !primaryAddr.isEmpty {
            return primaryAddr
        }
        return ""
    }

    private func getSecondaryAddr() -> String {
        if let secondaryAddr = self.secondaryAddr,
           !secondaryAddr.isEmpty {
            return secondaryAddr
        }
        return ""
    }
}
