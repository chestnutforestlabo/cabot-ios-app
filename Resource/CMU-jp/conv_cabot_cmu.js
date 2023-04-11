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
let tana = new RegExp("靴下|棚")
let regi = new RegExp("レジ|精算")
let find_person = new RegExp("(.*?)(さん|君|くん|ちゃん)?(を)?(探す|探して)")

function getResponse(request) {
    let text = request.input.text

    var speak = "すみません。もう一度お願いします。"
    var navi = false
    var dest_info = null
    var find_info = null

    if (text) {
	if (tana.test(text)) {
            speak = "わかりました。"
            navi = true
            dest_info = {
                "nodes": "EDITOR_node_1601605415482"
            }
        }else if (regi.test(text)) {
            speak = "わかりました。レジに向かいます。"
            navi = true
            dest_info = {
                "nodes": "EDITOR_node_1482995134771"
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
            "system":{
                "dialog_request_counter":0
            }
        }
    }
}
