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

@objcMembers
open class conv_cabot {

    fileprivate let domain = "hulop.navcog.ConversationV1"
    var running = false

    private let session = URLSession(configuration: .default)

    public init() {
    }

    func errorResponseDecoder(data: Data, response: HTTPURLResponse) -> RestError {

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
    
    private static let do_tabelka = try! NSRegularExpression(pattern: "どう食べるか|待ち合わせ|まちあわせ")
    private static let kutsushita = try! NSRegularExpression(pattern: "靴下")
    private static let taoru = try! NSRegularExpression(pattern: "タオル")
    private static let go_mujirushi = try! NSRegularExpression(pattern: "無印良品|無印|無地")
    private static let find_person = try! NSRegularExpression(pattern: "(.*?)(さん|君|くん|ちゃん)?(を)?(探す|探して)")
    private static let go_station = try! NSRegularExpression(pattern:"駅|帰")
    internal func _matches(_ text:String, regex: NSRegularExpression) -> Bool{
        return 0 < regex.matches(in: text, range:NSMakeRange(0, text.count)).count
    }
    internal func _at1(_ text:String, regex: NSRegularExpression) -> String?{
        if let match = regex.firstMatch(in: text, range:NSMakeRange(0, text.count)) {
            return String(text[Range(match.range(at: 1), in:text)!])
        }
        return nil
    }
    
    internal func _get_response(_ orgtext:String?) -> [String:Any]{
        var speak:String = "わかりません。もう一度お願いします。"
        var dest_info:[String:String]? = nil
        var find_info:[String:String]? = nil
        if let text = orgtext, !text.isEmpty{
            if self._matches(text, regex: conv_cabot.do_tabelka){
                speak = "わかりました。Do Tabelkaに向かいます"
                dest_info = [
                    "nodes": "EDITOR_node_1475144465320",
                ]
            }else if self._matches(text, regex: conv_cabot.kutsushita){
                speak = "コレドには無印良品とタビオがあります。"
            }else if self._matches(text, regex: conv_cabot.taoru){
                speak = "コレドには今治タオルと無印良品があります。"
            }else if self._matches(text, regex: conv_cabot.go_mujirushi){
                speak = "わかりました。無印良品に向かいます。"
                dest_info = [
                    "nodes": "EDITOR_node_1482995134771"
                ]
            }else if self._matches(text, regex: conv_cabot.find_person){
                if let target = self._at1(text, regex: conv_cabot.find_person) {
                    speak = "わかりました。\(target)さんを探します"
                    find_info = [
                        "name": "yamamoto" // ToDo: name mapping or send raw text
                    ]
                }
            }else if self._matches(text, regex: conv_cabot.go_station){
                speak = "わかりました。駅に向かいます。"
                dest_info = [
                    "nodes": "EDITOR_node_1599633337007"
                ]
            }
        }else{
            speak = "ご用件はなんでしょう？"
        }
        
        return [
            "output":[
                "log_messages":[],
                "text": [speak]
            ],
            "intents":[],
            "entities":[],
            "context":[
                "navi": (dest_info == nil && find_info == nil) ? false : true,
                "dest_info": dest_info,
                "find_info": find_info,
                "system":[
                    "dialog_request_counter":0
                ]
            ]
        ]
    }
    private let _msg_lock:NSLock = NSLock()
    public func message(
        _ text: String? = nil,
        server: String? = nil,
        api_key: String? = nil,
        client_id: String? = nil,
        context: Context? = nil,
        completionHandler: @escaping (RestResponse<MessageResponse>?, Error?) -> Void)
    {
        self._msg_lock.lock()
        defer{self._msg_lock.unlock()}
        if self.running {
            return
        }

        // construct body
        let messageRequest = MessageRequest(
            input: InputData(text: text ?? ""),
            context: context)
        guard let body = try? JSONEncoder().encodeIfPresent(messageRequest) else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            completionHandler(nil, error)
            return
        }
        
        /*let json = try! JSONSerialization.data(withJSONObject: [
            "output":[
                "log_messages":[],
                "text":[(text == nil || text!.isEmpty) ? "どこに行きますか": "そうですか"]
            ],
            "intents":[],
            "entities":[],
            "context":[
                "system":[
                    "dialog_request_counter":0
                ]
            ]
        ],options:[])*/
        let json = try! JSONSerialization.data(withJSONObject: self._get_response(text), options: [])
        
        let resmsg:MessageResponse = try! JSONDecoder().decode(MessageResponse.self, from:json)
        var res:RestResponse<MessageResponse> = RestResponse<MessageResponse>(statusCode: 200)
        res.result = resmsg
        /*DispatchQueue.global().asyncAfter(deadline: .now() + 1.0){
            completionHandler(res, nil)
        }*/
        DispatchQueue.global().async{
            completionHandler(res, nil)
        }
    }
}
