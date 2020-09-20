//
//  conv_cabot_en.swift
//  CaBot
//
//  Created by akhrksg on 2020/09/12.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation

class conv_cabot_en : conv_cabot{
    
    private static let elevator = try! NSRegularExpression(pattern:"elevator|Elevator")
    private static let subway = try! NSRegularExpression(pattern:"subway|station|Subway|Station")
    private static let dotavelka = try! NSRegularExpression(pattern:"cafe|eat|Cafe|Eat|Café|café")

    /*
     - # IBM Research - Tokyo
       title: IBM Research - Tokyo
       value: EDITOR_node_1589780736215
     - # 10F vending machine
       title: 10F vending machine
       value: EDITOR_node_1589781790959
     - # 11F vending machine
       title: 11F vending machine
       value: EDITOR_node_1589781245452
     - # IBM Japan entrance (1F)
       title: IBM Japan entrance (1F)
       value: EDITOR_node_1599730474821
     */
    private static let trl = try! NSRegularExpression(pattern:"research|Tokyo|Research")
    private static let vm10 = try! NSRegularExpression(pattern:"10")
    private static let vm11 = try! NSRegularExpression(pattern:"11")
    private static let entrance = try! NSRegularExpression(pattern:"entrance|Entrance")
    
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
            }else if self._matches(text, regex: conv_cabot_en.dotavelka){
                speak = "OK, going to Do Tabelka."
                dest_info = [
                    "nodes": "EDITOR_node_1475144465320",
                ]
            }else if self._matches(text, regex: conv_cabot_en.trl){
                speak = "OK, going to TRL."
                dest_info = [
                    "nodes": "EDITOR_node_1589780736215"
                ]
            }else if self._matches(text, regex: conv_cabot_en.vm10){
                speak = "OK, going to vending machine of 10th floor."
                dest_info = [
                    "nodes": "EDITOR_node_1589781790959"
                ]
            }else if self._matches(text, regex: conv_cabot_en.vm11){
                speak = "OK, going to vending machine of 11th floor."
                dest_info = [
                    "nodes": "EDITOR_node_1589781245452"
                ]
            }else if self._matches(text, regex: conv_cabot_en.entrance){
                speak = "OK, going to the entrance."
                dest_info = [
                    "nodes": "EDITOR_node_1599730474821"
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
