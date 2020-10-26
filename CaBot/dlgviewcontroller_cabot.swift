//
//  dlgviewcontroller_cabot.swift
//  CaBot
//
//  Created by akhrksg on 2020/09/01.
//  Copyright © 2020 CMU. All rights reserved.
//

import Foundation

class tts_cabot : TTSProtocol{
    
    private let _tts:NavDeviceTTS = NavDeviceTTS.shared()
    
    func speak(_ text: String?, callback: @escaping () -> Void) {
        self._tts.speak(text == nil ? "" : text, withOptions: nil, completionHandler: nil)
    }
    
    func stop() {
        self._tts.stop(true)
    }
    
    func stop(_ immediate: Bool) {
        self._tts.stop(immediate)
    }
    
    func vibrate() {
        //nop
    }
    
    func playVoiceRecoStart() {
        //nop
    }

}
class dlgviewcontroller_cabot : DialogViewController{
    private static let preflangid:[String:String] = [
        "ja": "ja-JP",
        "en": "en-US"
    ]
    private static let prefvoice:[String:[NSRegularExpression]] = [
        "ja-JP": [
            try! NSRegularExpression(pattern:"O-ren（拡張）"),
            try! NSRegularExpression(pattern:"O-ren")
        ]
    ]
    
    private func getpfeflangid() -> String{
        let pre = Locale(identifier: Locale.preferredLanguages[0])
        return dlgviewcontroller_cabot.preflangid[pre.languageCode ?? "ja"] ?? "ja-JP"
    }
    var _tts:TTSProtocol? = nil
    private let _tts_lock:NSLock = NSLock()
    override public var tts:TTSProtocol? {
        get{
            self._tts_lock.lock()
            defer{self._tts_lock.unlock()}
            let preflangid = self.getpfeflangid()
            if self._tts == nil{
                self._tts = SilverDefaultTTS(delegate: self.dialogViewHelper, _langid: preflangid, _criteria: dlgviewcontroller_cabot.prefvoice[preflangid])//tts_cabot()
            }
            return self._tts
        }
        set(value){
            self._tts = value
        }
    }
    
    override public func viewDidLoad() {
        self.baseHelper = DialogViewHelper()
        super.viewDidLoad()
    }
}
