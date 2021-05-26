//
//  dlgviewcontroller_muji.swift
//  CaBot
//
//  Created by akhrksg on 2020/10/07.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation
import HLPDialog

class dlgviewcontroller_muji : dlgviewcontroller_cabot{
    override func getConversation(pre: Locale) -> HLPConversation {
        return conv_cabot_mj()
    }
}
