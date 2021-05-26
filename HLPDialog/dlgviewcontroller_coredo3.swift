//
//  dlgviewcontroller_coredo3.swift
//  CaBot
//
//  Created by akhrksg on 2020/11/30.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation
import HLPDialog

class dlgviewcontroller_coredo3 : dlgviewcontroller_cabot{
    override func getConversation(pre: Locale) -> HLPConversation {
        return conv_cabot_coredo3()
    }
}
