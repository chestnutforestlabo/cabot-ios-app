/*******************************************************************************
 * Copyright (c) 2014, 2021  IBM Corporation, Carnegie Mellon University and others
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

let _dest_title_ext = {
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
    "伊織(今治タオル)":"美織|料理|庵|衣織|廬|伊織|タオル|今治",
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
}
var _destinations= {}

// custom global object Bundle
// Bundle.loadYaml returns a list of destination from a specified yaml file
Bundle.loadYaml("destinations_coredo_all").forEach(destination => {
    let title = destination["title"]
    let value = destination["value"]
    let pron = destination["pron"]
    let patternstr = _dest_title_ext[title] || title
    let regex = new RegExp(patternstr)
    _destinations[value] = {
        "title": title,
        "regex": regex,
        "value": value,
        "pron": pron
    }
    // custom global object Console
    // Console.log prints text in iOS console
    //Console.log(`${ title } ${ pron } ${ value } ${ patternstr }`)
})

function get_response(request) {
    let text = request.input.text

    var speak = "すみません。もう一度お願いします。"
    var navi = false
    var dest_info = null
    var output_pron = null
    if (text) {
        for (key in _destinations) {
            let dest = _destinations[key]
            let regex = dest["regex"]
            if (regex.test(text)) {
                speak = `わかりました。${dest["title"]}に向かいます。`
                output_pron = dest["pron"] ? `わかりました。${dest["pron"]}に向かいます。` : null
                navi = true
                dest_info = {
                    "nodes": dest["value"]
                }
            }
        }
    }else{
        speak = "ご用件はなんでしょう？"
    }
    return {
        "output": {
            "log_messages":[],
            "text": [speak]
        },
        "intents":[],
        "entities":[],
        "context":{
            "output_pron": output_pron,
            "navi": navi,
            "dest_info": dest_info,
            "system":{
                "dialog_request_counter":0
            }
        }
    }
}
