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


let do_tabelka = new RegExp( "どう食べるか|待ち合わせ|まちあわせ")
let kutsushita = new RegExp( "靴下")
let taoru = new RegExp( "タオル")
let go_mujirushi = new RegExp( "無印良品|無印|無地")
let find_person = new RegExp( "(.*?)(さん|君|くん|ちゃん)?(を)?(探す|探して)")
let go_station = new RegExp("駅|帰")

function get_response(request) {
    let text = request.input.text

    var speak = "すみません。もう一度お願いします。"
    var navi = false
    var dest_info = null
    var find_info = null
    
    if (text) {
	if (do_tabelka.test(text)){
            speak = "わかりました。Do Tabelkaに向かいます"
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1475144465320",
            }
        }else if (kutsushita.test(text)){
            speak = "コレドには無印良品とタビオがあります。"
        }else if (taoru.test(text)){
            speak = "コレドには今治タオルと無印良品があります。"
        }else if (go_mujirushi.test(text)){
            speak = "わかりました。無印良品に向かいます。"
	    navi = true
            dest_info = {
                // "nodes": "EDITOR_node_1482995134771" // 無印良品レジ
                "nodes": "EDITOR_node_1601661539802" // 無印良品(ギャラリー側出入口)
            }
        }else if (find_person.test(text)){
	    let r = find_person.exec(text)
	    if (r) {
                speak = `わかりました。${r[1]}さんを探します`
		navi = true
                find_info = {
                    "name": "yamamoto" // ToDo: name mapping or send raw text
                }
            }
        }else if (go_station.test(text)){
            speak = "わかりました。駅に向かいます。"
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1599633337007"
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
            "navi": navi,
            "dest_info": dest_info,
	    "find_info": find_info,
            "system":{
                "dialog_request_counter":0
            }
        }
    }
}
