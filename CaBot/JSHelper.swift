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
import JavaScriptCore
import Yams
import UIKit

@objc protocol JSBundleExport: JSExport {
    func loadYaml(_ name: String) -> [[String: String]]
    static func getInstance() -> JSBundle
}

class JSBundle: NSObject, JSBundleExport {
    func loadYaml(_ name: String) -> [[String: String]] {
        guard let path = Bundle.main.url(forResource: name, withExtension: "yaml", subdirectory: "Resource") else {
            return []
        }
        do {
            let content = try String(contentsOf: path)
            let yaml = try Yams.load(yaml: content) as! [[String: String]]
            return yaml
        } catch {
        }
        NSLog("Cannot load \(name).yaml")
        return []
    }
    class func getInstance() -> JSBundle {
        return JSBundle()
    }
}

@objc protocol JSConsoleExport: JSExport {
    func log(_ text: String) -> Void
    static func getInstance() -> JSConsole
}

class JSConsole: NSObject, JSConsoleExport {
    func log(_ text: String) {
        NSLog(text)
    }
    class func getInstance() -> JSConsole {
        return JSConsole()
    }
}

@objc protocol JSBluetoothExport: JSExport {
    func scanBeacons(_ uuid: JSValue, _ callback: JSValue)
    static func getInstance() -> JSBluetooth
}

class JSBluetooth: NSObject, JSBluetoothExport {
    var sampler: BeaconSampler?
    var callback: JSValue?
    var duration: Int = 0

    func scanBeacons(_ param: JSValue, _ callback: JSValue) {
        guard let json = param.toDictionary() as? [String: Any?] else { callback.call(withArguments: []); return }
        guard let uuids = json["uuids"] as? [String] else { callback.call(withArguments: []); return }
        guard let duration = json["duration"] as? Int else { callback.call(withArguments: []); return }

        sampler = BeaconSampler(with: uuids.map{ uuid in UUID(uuidString: uuid)! }) { beacons in
            if self.duration == 0 {
                self.sampler?.stop()
                return
            }
            self.duration -= 1
            var json:[String:Any?] = ["data":[]]
            guard let callback = self.callback else { return }
            guard beacons.count > 0 else {
                self.duration = 0
                self.sampler?.stop()
                callback.call(withArguments: [json])
                return
            }
            var data:[Any?] = []
            for beacon in beacons {
                data.append([
                    "uuid": beacon.uuid.uuidString,
                    "major": beacon.major,
                    "minor": beacon.minor,
                    "rssi": beacon.rssi
                ])
            }
            json["data"] = data
            callback.call(withArguments: [json])
        }
        self.callback = callback
        self.duration = duration
        sampler?.start()
    }

    class func getInstance() -> JSBluetooth {
        return JSBluetooth()
    }
}

@objc protocol JSHTTPSExport: JSExport {
    func postJSON(_ host:JSValue, _ json: JSValue, _ callback: JSValue)
    static func getInstance() -> JSHTTPS
}

class JSHTTPS: NSObject, JSHTTPSExport {
    func postJSON(_ host:JSValue, _ json: JSValue, _ callback: JSValue) {
        if let hostStr = host.toString() {
            if let json = json.toDictionary() as? [String: Any?] {

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    NSLog("%@, %@", hostStr, String(data: try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted), encoding: .utf8)!)
                    callback.call(withArguments: [[
                        "lat":40.44332302212961,
                        "lng":-79.94531616803428,
                        "floor":2.999999999999969
                    ]])
                }
            }
        }
    }
    class func getInstance() -> JSHTTPS {
        return JSHTTPS()
    }
}

@objc protocol JSDeviceExport: JSExport {
    var type:String { get }
    var id:String { get }
    static func getInstance() -> JSDevice
}

class JSDevice: NSObject, JSDeviceExport {
    var type:String {
        get {
            UIDevice.current.modelName
        }
    }
    var id:String {
        get {
            UIDevice.current.identifierForVendor?.uuidString ?? ""
        }
    }
    class func getInstance() -> JSDevice {
        return JSDevice()
    }
}

@objc protocol JSViewExport: JSExport {
    func showModalWaitingWithMessage(_ message: String)
    func hideModalWaiting()
    func alert(_ title: String, _ message: String)
    static func getInstance(withView view: UIViewController) -> JSView
}

class JSView: NSObject, JSViewExport {
    let view: UIViewController
    init(withView view: UIViewController) {
        self.view = view
    }
    func showModalWaitingWithMessage(_ message: String) {
        NavUtil.showModalWaiting(withMessage: message)
    }
    func hideModalWaiting() {
        NavUtil.hideModalWaiting()
    }
    func alert(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let ok = UIAlertAction(title: NSLocalizedString("Okay",
                                                            tableName: "CaBotLocalizable",
                                                            comment: "Okay"),
                                   style: .default) { (action:UIAlertAction) in
                alertController.dismiss(animated: true, completion: {
                })
            }
            alertController.addAction(ok)
            self.view.present(alertController, animated: true, completion: nil)
        }
    }
    class func getInstance(withView view: UIViewController) -> JSView {
        return JSView(withView: view)
    }
}

class JSHelper {
    let ctx: JSContext
    let script: String
    let view: UIViewController

    init(withScript jsFile: URL, withView view: UIViewController) {
        self.ctx = JSContext()
        self.view = view
        NSLog("loading \(jsFile)")

        do {
            script = try String(contentsOf: jsFile, encoding: .utf8)

            // JavaScript syntax check
            ctx.exceptionHandler = { context, value in
                let lineNumber:Int = Int(value!.objectForKeyedSubscript("line")!.toInt32())
                guard lineNumber > 0 else { return }
                let moreInfo = "\(jsFile.path)#L\(lineNumber)"
                NSLog("JS ERROR: \(value!) \(moreInfo)")
                let start = max(lineNumber-2, 0)
                for i in (start)..<lineNumber {
                    NSLog("L%-4d %s", i+1, String(self.script.split(separator: "\n", omittingEmptySubsequences:false)[i]))
                }
                exit(0)
            }
            // set custom global objects
            ctx.setObject(JSBundle.getInstance(), forKeyedSubscript: "Bundle" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSConsole.getInstance(), forKeyedSubscript: "Console" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSBluetooth.getInstance(), forKeyedSubscript: "Bluetooth" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSHTTPS.getInstance(), forKeyedSubscript: "HTTPS" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSView.getInstance(withView: view), forKeyedSubscript: "View" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSDevice.getInstance(), forKeyedSubscript: "Device" as (NSCopying & NSObjectProtocol))
            // load script
            ctx.evaluateScript(script)
        } catch {
            script = ""
            NSLog("Cannot load the script \(jsFile.path)")
            exit(0)
        }
    }

    func call(_ funcName:String, withArguments args: [Any]) -> JSValue! {
        if let funk = ctx.objectForKeyedSubscript(funcName) {
            guard !funk.isUndefined else { NSLog("\(funcName) is not defined"); return funk }
            guard !funk.isNull else { NSLog("\(funcName) is null"); return funk }
            return funk.call(withArguments: args)
        }
        return nil
    }

}
