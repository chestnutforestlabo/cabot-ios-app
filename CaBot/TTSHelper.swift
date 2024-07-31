/*******************************************************************************
 * Copyright (c) 2021  Carnegie Mellon University
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

import Foundation
import AVKit
import HLPDialog
import SwiftUI


protocol CaBotTTSDelegate {
    func getModeType() -> ModeType
    func activityLog(category:String, text:String, memo:String)
    func share(user_info:SharedInfo)
}

class CaBotTTS : TTSProtocol{

    var voice: AVSpeechSynthesisVoice?
    var rate: Double = 0.6
    var isSpeaking: Bool {
        get {
            self._tts.isSpeaking()
        }
    }
    var delegate:CaBotTTSDelegate?

    init(voice: AVSpeechSynthesisVoice?) {
        self.voice = voice
    }

    private let _tts:NavDeviceTTS = NavDeviceTTS.shared()

    func reset() {
        self._tts.reset()
    }

    func speak(_ text: String?, forceSelfvoice: Bool, force: Bool, callback: @escaping (Int32) -> Void, progress: ((NSRange) -> Void)? = nil) {
//        guard self.delegate?.getModeType() == .Normal else { return }
        let isForeground = UIApplication.shared.applicationState == .active
        let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        let selfspeak = forceSelfvoice || !isForeground || !isVoiceOverRunning

        var voiceover = false
        if UIAccessibility.isVoiceOverRunning {
            voiceover = true
        }
        self.delegate?.activityLog(category: "app speech speaking", text: text ?? "", memo: "force=\(force)")

        var options:Dictionary<String,Any> = ["rate": rate, "selfspeak": selfspeak, "force": force]
        if let voice = self.voice {
            options["voice"] = voice
        }
        self._tts.speak(text == nil ? "" : text, withOptions: options, completionHandler: { code in
            if code > 0 {
                self.delegate?.activityLog(category: "app speech completed", text: text ?? "", memo: "force=\(force)")
            } else {
                self.delegate?.activityLog(category: "app speech canceled", text: text ?? "", memo: "force=\(force)")
            }
            callback(code)
            //print("code=\(code), text=\(text)")
            if code >= 0, let text = text {
                self.delegate?.share(user_info: SharedInfo(type: .SpeakProgress, value: text, flag1: true, flag2: voiceover, length: Int(code)))
            }
        }, progressHandler: { text, count, range in
            if let progress = progress{
                progress(range)
            }
            if let text = text {
                //print(count, range, text)
                if count == 1 {
                    self.delegate?.share(user_info: SharedInfo(type: .Speak, value: text, flag1: force, flag2: voiceover))
                }

                self.delegate?.share(user_info: SharedInfo(type: .SpeakProgress, value: text, location: range.location, length: range.length))
            }
        })
    }

    func speakForAdvanced(_ text:String?, force: Bool, callback: @escaping (Int32) -> Void) {
        var options:Dictionary<String,Any> = ["rate": rate, "selfspeak": true, "force": force]
        if let voice = self.voice {
            options["voice"] = voice
        }
        self._tts.speak(text == nil ? "" : text, withOptions: options, completionHandler: { code in
            callback(code)
        }, progressHandler: { text, count, range in
        })
    }

    func stopSpeakForAdvanced() {
        self._tts.stop(false)
    }

    func speak(_ text: String?, force: Bool, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: force, callback: callback)
    }

    // to conform to TTSProtocol for HLPDialog
    func speak(_ text:String?, callback: @escaping ()->Void) {
        self.speak(text) { _ in
            callback()
        }
    }

    func speak(_ text: String?, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: false, callback: callback)
    }

    func stop() {
        self.delegate?.share(user_info: SharedInfo(type: .Speak, value: "", flag1: true))
        self._tts.stop(true)
    }

    func stop(_ immediate: Bool) {
        self.delegate?.share(user_info: SharedInfo(type: .Speak, value: "", flag1: true))
        self._tts.stop(immediate)
    }

    func vibrate() {
        //nop
    }

    func playVoiceRecoStart() {
        //nop
    }
}


struct Voice: Hashable {
    static func == (lhs: Voice, rhs: Voice) -> Bool {
        lhs.AVvoice.identifier == rhs.AVvoice.identifier
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(AVvoice.identifier)
    }
    var id: String {
        get {
            AVvoice.identifier
        }
    }

    let AVvoice: AVSpeechSynthesisVoice

}

class TTSHelper {
    static func getVoice(by id:String) -> Voice? {
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            if voice.identifier == id {
                return Voice(AVvoice: voice)
            }
        }
        return nil
    }
    static func getVoices(by locale: Locale) -> [Voice] {
        let search = locale.identifier

        var voices:[Voice] = []
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            if voice.language == search {
                voices.append(Voice(AVvoice: voice))
            }
        }
        if voices.count == 0 {
            let search = String(locale.identifier.prefix(2))
            for voice in AVSpeechSynthesisVoice.speechVoices() {
                if voice.language.starts(with: search) {
                    voices.append(Voice(AVvoice: voice))
                }
            }
        }

        return voices
    }

    static func playSample(of voice:Voice, at rate: Double = 0.5) {
        let tts = CaBotTTS(voice: voice.AVvoice)
        tts.rate = rate

        tts.speak(CustomLocalizedString("Hello Suitcase!", lang: voice.AVvoice.language), forceSelfvoice:true, force:true) {_ in

        }
    }
}
