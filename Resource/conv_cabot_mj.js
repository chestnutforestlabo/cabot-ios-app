let tana = new RegExp("靴下|棚")
let regi = new RegExp("レジ|精算")
let find_person = new RegExp("(.*?)(さん|君|くん|ちゃん)?(を)?(探す|探して)")

function get_response(request) {
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
