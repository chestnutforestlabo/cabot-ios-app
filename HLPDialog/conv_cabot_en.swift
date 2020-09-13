//
//  conv_cabot_en.swift
//  CaBot
//
//  Created by akhrksg on 2020/09/12.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation

class conv_cabot_en : conv_cabot{
    
    private static let elevator = try! NSRegularExpression(pattern:"elevator")
    private static let subway = try! NSRegularExpression(pattern:"subway|station")
    internal override func _get_response(_ orgtext:String?) -> [String:Any]{
        var speak:String = "Sorry, I couldn't catch you."
        var dest_info:[String:String]? = nil
        if let text = orgtext, !text.isEmpty{
            if self._matches(text, regex: conv_cabot_en.elevator){
                speak = "OK, going to the elevator."
                dest_info = [
                    "nodes": "EDITOR_node_1474876589541",
                ]
            }else if self._matches(text, regex: conv_cabot_en.subway){
                speak = "OK, going to the subway station."
                dest_info = [
                    "nodes": "EDITOR_node_1599633337007"
                ]
            }
        }else{
            speak = "Where are you going?"
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
