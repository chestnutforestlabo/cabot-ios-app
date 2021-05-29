//
//  dlgviewcontroller_coredo3.swift
//  CaBot
//
//  Created by akhrksg on 2020/11/30.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation
import HLPDialog

class DialogViewControllerLocal : DialogViewControllerCabot{
    var identifier: String? = nil

    override func getConversation(pre: Locale) -> HLPConversation {
        return LocalConversation(withScript: identifier ?? "")
    }
}
