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
import HLPDialog

class CaBotTTS : TTSProtocol{

    var voice: AVSpeechSynthesisVoice?

    init(voice: AVSpeechSynthesisVoice?) {
        self.voice = voice
    }

    private let _tts:NavDeviceTTS = NavDeviceTTS.shared()

    func speak(_ text: String?, callback: @escaping () -> Void) {
        if let voice = self.voice {
            self._tts.speak(text == nil ? "" : text, withOptions: ["voice": voice], completionHandler: callback)
        } else {
            self._tts.speak(text == nil ? "" : text, withOptions: [:], completionHandler: callback)
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
class DialogViewControllerCabot : DialogViewController{
    var modelURL: URL?
    var voice: AVSpeechSynthesisVoice?

    override func viewDidLoad() {
        self.tts = CaBotTTS(voice: self.voice!)
        //self.tts = SilverDefaultTTS()

        if self.baseHelper == nil {
            self.baseHelper = DialogViewHelper()
        }
    }

    override func getConversation(pre: Locale) -> HLPConversation {
        return LocalConversation(withScript: modelURL!)
    }
}
