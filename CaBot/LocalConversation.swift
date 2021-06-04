/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
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
import RestKit
import AssistantV1
import HLPDialog
import JavaScriptCore
import Yams

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


class LocalConversation: HLPConversation {

    fileprivate let domain = "cabot.LocalConversation"
    let ctx: JSContext
    let script: String

    init(withScript jsFile: URL) {
        ctx = JSContext()
        NSLog("loading \(jsFile)")

        do {
            script = try String(contentsOf: jsFile, encoding: .utf8)

            // JavaScript syntax check
            ctx.exceptionHandler = { context, value in
                let lineNumber:Int = Int(value!.objectForKeyedSubscript("line")!.toInt32())
                let moreInfo = "\(jsFile.path)#L\(lineNumber)"
                NSLog("JS ERROR: \(value!) \(moreInfo)")
                for i in (lineNumber-2)..<lineNumber {
                    NSLog("L\(i+1)",self.script.split(separator: "\n", omittingEmptySubsequences:false)[i])
                }
                exit(0)
            }
            // set custom global objects
            ctx.setObject(JSBundle.getInstance(), forKeyedSubscript: "Bundle" as (NSCopying & NSObjectProtocol))
            ctx.setObject(JSConsole.getInstance(), forKeyedSubscript: "Console" as (NSCopying & NSObjectProtocol))
            // load script
            ctx.evaluateScript(script)
        } catch {
            script = ""
            NSLog("Cannot load the script \(jsFile.path)")
            exit(0)
        }
    }

    public func errorResponseDecoder(data: Data, response: HTTPURLResponse) -> RestError {

        let statusCode = response.statusCode
        var errorMessage: String?
        var metadata = [String: Any]()

        do {
            let json = try JSONDecoder().decode([String: JSON].self, from: data)
            metadata = [:]
            if case let .some(.string(message)) = json["error"] {
                errorMessage = message
            }
            // If metadata is empty, it should show up as nil in the RestError
            return RestError.http(statusCode: statusCode, message: errorMessage, metadata: !metadata.isEmpty ? metadata : nil)
        } catch {
            return RestError.http(statusCode: statusCode, message: nil, metadata: nil)
        }
    }

    public func _get_response(_ request: Any) -> [String:Any] {
        if let funk = ctx.objectForKeyedSubscript("get_response") {
            NSLog(request)
            if let ret = funk.call(withArguments: [request]) {
                return ret.toDictionary() as! [String: Any]
            }
        }
        return [:]
    }

    public func message(
        _ text: String? = nil,
        server: String,
        api_key: String,
        client_id: String? = nil,
        context: Context? = nil,
        completionHandler: @escaping (RestResponse<MessageResponse>?, Error?) -> Void)
    {
        // construct body
        let messageRequest = MessageRequest(
            input: InputData(text: text ?? ""),
            context: context)

        guard let request = try? JSONSerialization.jsonObject(with: JSONEncoder().encodeIfPresent(messageRequest)) else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            completionHandler(nil, error)
            return
        }

        let json = try! JSONSerialization.data(withJSONObject: self._get_response(request), options: [])
        let resmsg:MessageResponse = try! JSONDecoder().decode(MessageResponse.self, from:json)
        var res:RestResponse<MessageResponse> = RestResponse<MessageResponse>(statusCode: 200)
        res.result = resmsg
        DispatchQueue.global().async{
            completionHandler(res, nil)
        }
    }
}
