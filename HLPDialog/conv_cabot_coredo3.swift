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
import Yams

class conv_cabot_coredo3 : conv_cabot{
    
    private static let _dest_title_ext:[String:String] = [
        "COREDO室町＋": "コレド室町プラス",
        "collex": "小レックス|これっくす|コレックス",
        "無印良品":"無印",
        "ちばぎんひまわりギャラリー":"ちばぎんひまわりギャラリー|ひまわり",
        "まかないこすめ": "まかないこすめ|まかないコスメ",
        "ポーカーフェイス トーキョー トラディション":"ポーカーフェイス|東京|トラディション",
        "タビオ(靴下)":"タビオ|靴下",
        "Simply":"シンプリー",
        "橋楽亭／囲庵": "蕎楽亭|メグリア",
        "efffy": "笑フィー|エフィー",
        "IDEE SHOP": "出井ショップ|イデーショップ",
        "伊織(今治タオル)":"伊織|タオル|今治",
        "LIVETART": "リベッターと|裏βと",
        "DO TABELKA": "どう食べるか|ドゥータベルカ|どー食べるか|どーたべるか",
        "中川政七商店": "中川政七",
        "漆器 山田平安堂": "漆器|山田平安堂",
        "SUSgallery": "さすがギャラリー",
        "CLASKA Gallery ＆ Shop \\“DO\\”": "クラスカ",
        "石見銀山　群言堂":"石見銀山|群言動|群言堂",
        "鶴屋吉信": "鶴屋",
        "茅乃舎": "茅乃舎|茅の家",
        "TOMIZ": "トミーズ|とみーず",
        "BOULANGE": "ブール杏樹|ブーランジェ|ブーランジュ",
        "IL BACARO ALMA": "いるばーか|6歩間|６歩間|入る婆角歩間"
    ]
    var _destinations:[String:Any] = [:]
    
    override init() {
        // load destination yaml and make destination list
        if let yamlfile = Bundle.main.path(forResource: "destinations_coredo_all"/*"destinations"*/, ofType: "yaml") {
            if let yaml = try? String(contentsOfFile: yamlfile) {
                if let destinations = try? Yams.load(yaml: yaml) as? [[String:String]] {
                    for destination in destinations {
                        let patternstr:String = conv_cabot_coredo3._dest_title_ext[destination["title"]!] ?? destination["title"]!
                        if let regex = try? NSRegularExpression(pattern: patternstr){
                            self._destinations[destination["value"]!] = [
                                "title":destination["title"]!,
                                "regex": regex, "value": destination["value"]!,
                                "pron": destination["pron"]!
                            ]
                        }
                    }
                }
            }
        }
    }

    internal override func _get_response(_ orgtext:String?) -> [String:Any]{
        var speak:String = "すみません。もう一度お願いします。"
        var dest_info:[String:String]? = nil
        var output_pron:String? = nil
        if let text = orgtext, !text.isEmpty{
            for (key, value) in self._destinations{
                if let val = value as? [String:Any] {
                    if self._matches(text, regex:val["regex"] as! NSRegularExpression){
                        let title = val["title"] as! String
                        speak = "わかりました。" + title + "に向かいます。"
                        dest_info = [
                            "nodes": val["value"] as! String
                        ]
                        if let pron = val["pron"] as? String{
                            output_pron = "わかりました。 " + pron + " に向かいます。"
                        }
                    }
                }
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
                "output_pron": output_pron,
                "navi": dest_info == nil ? false : true,
                "dest_info": dest_info,
                "system":[
                    "dialog_request_counter":0
                ]
            ]
        ]
    }
}
