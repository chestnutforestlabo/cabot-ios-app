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

class conv_cabot_mj : conv_cabot{
    
    private static let tana = try! NSRegularExpression(pattern:"靴下|棚")
    private static let taoru = try! NSRegularExpression(pattern: "タオル")
    private static let go_mujirushi = try! NSRegularExpression(pattern: "無印良品|無印|無地")
    private static let reji = try! NSRegularExpression(pattern: "レジ|精算")
    private static let find_person = try! NSRegularExpression(pattern: "(.*?)(さん|君|くん|ちゃん)?(を)?(探す|探して)")

    internal override func _get_response(_ orgtext:String?) -> [String:Any]{
        var speak:String = "わかりません。もう一度お願いします。"
        var dest_info:[String:String]? = nil
        var find_info:[String:String]? = nil
        if let text = orgtext, !text.isEmpty{
            if self._matches(text, regex: conv_cabot_mj.tana){
                speak = "わかりました。"
                dest_info = [
                    "nodes": "EDITOR_node_1475151657340"
                ]
            }else if self._matches(text, regex: conv_cabot_mj.reji){
                speak = "わかりました。レジに向かいます。"
                dest_info = [
                    "nodes": "EDITOR_node_1495222818017"
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
                "navi": dest_info == nil ? false : true,
                "dest_info": dest_info,
                "system":[
                    "dialog_request_counter":0
                ]
            ]
        ]
    }
}
