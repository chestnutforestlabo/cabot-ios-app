//
//  dlgviewcontroller_muji.swift
//  CaBot
//
//  Created by akhrksg on 2020/10/07.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation

class dlgviewcontroller_hnd : dlgviewcontroller_cabot{
    internal override func getconversation(pre: Locale) -> conv_cabot{
        return conv_cabot_hnd()
    }
}
