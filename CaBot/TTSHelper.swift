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
import PriorityQueueTTS


protocol CaBotTTSDelegate {
    func getModeType() -> ModeType
    func activityLog(category:String, text:String, memo:String)
    func share(user_info:SharedInfo)
}

struct SpeakTag {
    let tag :String
    let erase :Bool
    init(tag: String, erase: Bool = false) {
        self.tag = tag
        self.erase = erase
    }
}


typealias ProgressHandler = (String?,Int,NSRange)->Void

class CaBotTTS : TTSProtocol {

    var voice: AVSpeechSynthesisVoice? {
        didSet {
            self._tts.voice = voice
        }
    }
    var lang: String?
    var rate: Double = 0.6 {
        didSet {
            self._tts.speechRate = Float(rate)
        }
    }
    
    var isSpeaking: Bool {
        get {
            self._tts.isSpeaking
        }
    }
    var delegate:CaBotTTSDelegate?

    init(voice: AVSpeechSynthesisVoice?, lang: String? = nil ) {
        self.voice = voice
        self.lang = lang
        _tts.delegate = self
        _tts.speechRate = 0.6
        _tts.start()
    }

    private let _tts = PriorityQueueTTS.shared
    private var _progressHandlers = [UUID : ProgressHandler]()


    func speak(_ text: String?, forceSelfvoice: Bool, force: Bool, priority: SpeechPriority = .Normal, timeout sec : TimeInterval? = nil, tag:SpeakTag? = nil, callback: @escaping (Int32) -> Void, progress: ((NSRange) -> Void)? = nil) {
        guard self.delegate?.getModeType() == .Normal else { return }
        
        // - pendding - fix voiceover
        // let isForeground = UIApplication.shared.applicationState == .active
        // let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        // let selfspeak = forceSelfvoice || !isForeground || !isVoiceOverRunning
        
        if force {
            self._tts.stop( true )
            Debug(log:"<TTS> force stop tts by \(text?._summary(15) ?? "")")
        }

        var voiceover = false
        if UIAccessibility.isVoiceOverRunning {
            voiceover = true
        }
        self.delegate?.activityLog(category: "app speech speaking", text: text ?? "", memo: "force=\(force)")


        self._speak(text == nil ? "" : text!, priority:priority, timeout :sec, tag: tag, completionHandler: { utext, code in
            if code > 0 {
                self.delegate?.activityLog(category: "app speech completed", text: text ?? "", memo: "force=\(force)")
            } else {
                self.delegate?.activityLog(category: "app speech canceled", text: text ?? "", memo: "force=\(force)")
            }
            callback(code)
            //print("code=\(code), text=\(text)")
            if code >= 0, let text = utext {
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

    func speakForAdvanced(_ text:String?, force: Bool, tag:SpeakTag? = nil, callback: @escaping (Int32) -> Void) {
        self._speak(text == nil ? "" : text!, priority:.parse(force:force, mode:.Advanced), tag: tag, completionHandler: { utext, code in
            callback(code)
        }, progressHandler: { text, count, range in
        })
    }

    func stopSpeakForAdvanced() {
        self._tts.stop(false)
    }

    func speak(_ text: String?, force: Bool, priority: CaBotTTS.SpeechPriority, timeout sec : TimeInterval? = nil, tag:SpeakTag? = nil, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: force, priority: priority, timeout: sec, tag: tag, callback: callback)
    }

    // to conform to TTSProtocol for HLPDialog
    func speak(_ text:String?, callback: @escaping ()->Void) {
        self.speak(text, priority: .Normal, timeout:nil, callback: callback)
    }
    
    func speak(_ text:String?, priority: SpeechPriority, timeout sec : TimeInterval? = nil, tag: SpeakTag? = nil, callback: @escaping ()->Void) {
        self.speak(text, priority:priority, timeout:sec, tag:tag ) { _ in
            callback()
        }
    }

    func speak(_ text: String?, priority: SpeechPriority, timeout sec : TimeInterval?, tag: SpeakTag? = nil, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: false, priority:priority, timeout: sec, tag: tag, callback: callback)
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

        tts.speak(CustomLocalizedString("Hello Suitcase!", lang: voice.AVvoice.language), forceSelfvoice:true, force:true, priority:.High ) {_ in
        }
    }
}

extension CaBotTTS : PriorityQueueTTSDelegate {
    
    public enum SpeechPriority {
        case Low
        case Normal
        case High
        case Required
        
        public init( queuePriority: SpeechQueuePriority ) {
            switch queuePriority {
            case .Low:
                self = .Low
            case .Normal:
                self = .Normal
            case .High:
                self = .High
            case .Required:
                self = .Required
            }
        }
        
        var queuePriority : SpeechQueuePriority {
            switch self {
            case .Low:
                return .Low
            case .Normal:
                return .Normal
            case .High:
                return .High
            case .Required:
                return .Required
            }
        }
    }
    
    func _speak( _ text:String, priority:SpeechPriority, timeout sec : TimeInterval? = nil, tag:SpeakTag? = nil, completionHandler:@escaping (String?, Int32)->Void, progressHandler: ((String?,Int,NSRange)->Void)? = nil ) {
        
        
        let entry = TokenizerEntry( separators:separators, priority:priority.queuePriority, timeout_sec: (sec ?? 90.0), tag: (tag?.tag ?? Tag.Default) ) { [weak self] entry, token, reason in
            
            if reason == .Completed || reason == .Canceled {
                self?._progressHandlers[entry.uuid] = nil
            }
            
            let compLen = Int32((reason != .Canceled ? token?.text?.count : nil) ?? -1)
            Debug(log:"<TTS> complate token:\(token?.text ?? "") reason:\(reason)")
            completionHandler( token?.text, compLen )
        }
        try! entry.append(text: text)
        entry.close()
        _progressHandlers[entry.uuid] = progressHandler
        
        if let tag {
            let removing = tag.erase ? SameTag : nil
            self._tts.append(entry: entry, withRemoving: removing, cancelBoundary: .immediate)
            Debug(log:"<TTS> request text:\(text._summary()) priority:\(priority) \("timeout"._dump(of:sec)) tag:\(tag.tag)(erase:\(tag.erase)")
        }
        else {
            self._tts.append(entry: entry)
            Debug(log:"<TTS> request text:\(text._summary()) priority:\(priority)")
        }
    }
    
    var separators :[String] {
        let key = "TOKEN_SEPARATORS"
        let testLang = self.lang ?? self.voice?.language
        if let testLang {
            let res = CustomLocalizedString(key, lang: testLang)
            if res != key {
                let splits = res.components(separatedBy: ";")
                if splits.count > 0 {
                    return splits
                }
            }
        }
        let res = NSLocalizedString(key, value: ". ", comment: "")
        return res.components(separatedBy: ";")
    }
    
    func progress(queue: PriorityQueueTTS, entry: QueueEntry) {
        guard let token = entry.token else { return }
        
        Debug(log:"<TTS> progress token:\(token.text ?? "") pos:\(token.bufferedRange.range.location) len:\(token.bufferedRange.range.length)")
        
        _progressHandlers[entry.uuid]?( token.text, token.bufferedRange.progressCount, token.bufferedRange.range );
    }
    
    func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
    }
}


extension CaBotTTS.SpeechPriority {
    
    static func parse( force: Bool? = nil, priority: Int32? = nil, priorityBias: Bool = false, mode: ModeType = .Normal ) -> Self {
        
        // now, `mode`, `priorityBias` is not use. (for using priority bias)
        if force == true, priority == nil {
            return .High
        }
        
        if let priority {
            switch priority {
            case _ where priority <= 25:
                return .Low
            case 26 ... 50:
                return .Normal
            case 51 ... 75:
                return .High
            default:
                return .Required
            }
        }
        return .Normal
    }
}


extension PriorityQueueTTS {

    func stop( _ immediate:Bool ) {
        self.stopSpeaking(at: immediate ? .immediate : .word)
    }
}


extension String {
    
    func _summary( _ limit: Int = 25 ) -> String {
        let count = self.count
        return (count > limit) ? "\(self.prefix(limit))... (\(count))" : "\(self) (len:\(count))"
    }
    
    func _dump<T>( of val :T? ) -> String {
        guard let val else { return "" }
        return " \(self):\(val)"
    }
}
