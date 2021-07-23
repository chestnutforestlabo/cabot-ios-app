// please remove this line
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

class CaBotTTS : TTSProtocol{

    var voice: AVSpeechSynthesisVoice?
    var rate: Double = 0.6

    init(voice: AVSpeechSynthesisVoice?) {
        self.voice = voice
    }

    private let _tts:NavDeviceTTS = NavDeviceTTS.shared()

    func speak(_ text: String?, force: Bool, callback: @escaping () -> Void) {
        if let voice = self.voice {
            self._tts.speak(text == nil ? "" : text, withOptions: ["voice": voice, "rate": rate, "selfspeak": true, "force": force], completionHandler: callback)
        } else {
            self._tts.speak(text == nil ? "" : text, withOptions: ["rate": rate, "selfspeak": true, "force": force], completionHandler: callback)
        }
    }

    func speak(_ text: String?, callback: @escaping () -> Void) {
        if let voice = self.voice {
            self._tts.speak(text == nil ? "" : text, withOptions: ["voice": voice, "rate": rate, "selfspeak": true], completionHandler: callback)
        } else {
            self._tts.speak(text == nil ? "" : text, withOptions: ["rate": rate, "selfspeak": true], completionHandler: callback)
        }
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
        return voices
    }

    static func playSample(of voice:Voice, at rate: Double = 0.5) {
        let tts = CaBotTTS(voice: voice.AVvoice)
        tts.rate = rate

        tts.speak(NSLocalizedString("Hello Suitcase!", comment: ""), force: true) {

        }
    }
}
