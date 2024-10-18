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


typealias ProgressHandler = (String?,Int,NSRange)->Void

class CaBotTTS : TTSProtocol {

    var voice: AVSpeechSynthesisVoice?
    var lang: String?
    var rate: Double = 0.6
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
        _tts.start()
    }

    private let _tts = PriorityQueueTTS.shared
    private var _progressHandlers = [UUID : ProgressHandler]()


    func speak(_ text: String?, forceSelfvoice: Bool, force: Bool, priority: SpeechPriority = .Normal, callback: @escaping (Int32) -> Void, progress: ((NSRange) -> Void)? = nil) {
        guard self.delegate?.getModeType() == .Normal else { return }
        let isForeground = UIApplication.shared.applicationState == .active
        let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        //FIXME: !selfspeak での VO呼び出し
        let selfspeak = forceSelfvoice || !isForeground || !isVoiceOverRunning

        var voiceover = false
        if UIAccessibility.isVoiceOverRunning {
            voiceover = true
        }
        self.delegate?.activityLog(category: "app speech speaking", text: text ?? "", memo: "force=\(force)")


        self._speak(text == nil ? "" : text!, priority:priority, completionHandler: { utext, code in
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

    func speakForAdvanced(_ text:String?, force: Bool, callback: @escaping (Int32) -> Void) {
        self._speak(text == nil ? "" : text!, priority:.parse(force:force, mode:.Advanced), tag:ModeType.Advanced.rawValue, completionHandler: { utext, code in
            callback(code)
        }, progressHandler: { text, count, range in
        })
    }

    func stopSpeakForAdvanced() {
        self._tts.stop(false)
    }

    func speak(_ text: String?, force: Bool, priority: SpeechPriority, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: force, priority: priority, callback: callback)
    }

    // to conform to TTSProtocol for HLPDialog
    func speak(_ text:String?, callback: @escaping ()->Void) {
        self.speak(text, priority: .Normal, callback: callback)
    }
    
    func speak(_ text:String?, priority: SpeechPriority, callback: @escaping ()->Void) {
        self.speak(text, priority:priority ) { _ in
            callback()
        }
    }

    func speak(_ text: String?, priority: SpeechPriority, callback: @escaping (Int32) -> Void) {
        self.speak(text, forceSelfvoice: false, force: false, priority:priority, callback: callback)
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

        tts.speak(CustomLocalizedString("Hello Suitcase!", lang: voice.AVvoice.language), forceSelfvoice:true, force:true, priority:.Required ) {_ in
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
    
    func _speak( _ text:String, priority:SpeechPriority, tag:Tag? = nil, completionHandler:@escaping (String?, Int32)->Void, progressHandler: ((String?,Int,NSRange)->Void)? = nil ) {

        let entry = TokenizerEntry( separators:separators, priority:priority.queuePriority, timeout_sec: 90.0, tag: (tag ?? Tag.Default), speechRate:Float(rate), voice:voice ) { [weak self] entry, utterance, reason in
            if reason != .Paused {
                self?._progressHandlers[entry.uuid] = nil
            }
            
            let compLen = Int32((reason != .Canceled ? utterance?.speechString.count : nil) ?? -1)
            
            completionHandler( utterance?.speechString, compLen )
        }
        try! entry.append(text: text)
        entry.close()
        _progressHandlers[entry.uuid] = progressHandler
        
        if let _ = tag {
            self._tts.append(entry: entry, withRemoving: SameTag, cancelBoundary: .immediate)
        }
        else {
            self._tts.append(entry: entry)
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
        guard let handler = _progressHandlers[entry.uuid], let token = entry.token
        else { return }
        handler( token.text, token.bufferedRange.progressCount, token.bufferedRange.range );
    }
    
    func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
    }
}


extension CaBotTTS.SpeechPriority {
    
    static func parse( force: Bool? = nil, priority: Int32? = nil, mode:ModeType = .Normal ) -> Self {
        if let force, force == true { return .Required }
        
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
        self.cancel( at:immediate ? .immediate : .word )
    }
}
