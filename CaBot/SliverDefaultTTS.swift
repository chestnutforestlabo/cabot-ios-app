//
//  SliverDefaultTTS.swift
//  CaBot
//
//  Created by akhrksg on 2020/09/01.
//  Copyright © 2020 CMU. All rights reserved.
//

import UIKit
import AVFoundation

class SynthesizerHelper: NSObject, AVSpeechSynthesizerDelegate {
    
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        NSLog("didCancelSpeechUtterance \(utterance.speechString)")
    }
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        NSLog("didContinueSpeechUtterance \(utterance.speechString)")
    }
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NSLog("didFinishSpeechUtterance \(utterance.speechString)")
        
        if let callback = map[utterance.speechString] {
            map[utterance.speechString] = nil
            
            DispatchQueue.main.async(execute: {
                callback()
            })
        }
        
    }
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        NSLog("didPauseSpeechUtterance \(utterance.speechString)")
    }
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        NSLog("didStartSpeechUtterance \(utterance.speechString)")
    }
    
    @objc func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
    }
    
    var map:[String:() -> Void] = [:]
}

class Synthesizer {
    
    fileprivate static let synthesizer = AVSpeechSynthesizer()
    fileprivate static let delegate = SynthesizerHelper()
    fileprivate static var voice = AVSpeechSynthesisVoice(language: "ja-JP")
    
    private static var rate:Float = AVSpeechUtteranceDefaultSpeechRate//mostly 0.5
    
    class func setRate(val: Float){
        if val > 0{
            rate = AVSpeechUtteranceDefaultSpeechRate * val
        }
    }
    class func setLanguege(_ langid:String){
        voice = AVSpeechSynthesisVoice(language:langid);
    }
    class func getVoiceLangId() -> String?{
        return self.voice?.language
    }
    class func _matches(_ text:String, regex: NSRegularExpression) -> Bool{
        return 0 < regex.matches(in: text, range:NSMakeRange(0, text.count)).count
    }
    class func searchPreferredVoice(_ criteria:[NSRegularExpression]){
        //debug
        /*for tmp in AVSpeechSynthesisVoice.speechVoices() {
            if #available(iOS 10.0, *) {
                if (tmp.language == voice!.language) {
                    print(tmp.name)
                }
            }
        }*/
        var found:[NSRegularExpression:AVSpeechSynthesisVoice] = [:]
        
        for tmp in AVSpeechSynthesisVoice.speechVoices() {
            if #available(iOS 10.0, *) {
                if (tmp.language == voice!.language) {
                    for rgx in criteria{
                        if self._matches(tmp.name, regex: rgx){
                            found[rgx] = tmp
                        }
                    }
                }
            }
        }
        for rgx in criteria{
            if let vc = found[rgx]{
                //debug
                print("voice name = " + vc.name)
                self.voice = vc
                return
            }
        }
    }
    
    class func stopSpeakingUtterance() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    class func _init_audio_session(){
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.defaultToSpeaker, .mixWithOthers,.allowBluetooth, .allowBluetoothA2DP])
        //try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, mode: AVAudioSessionModeMeasurement, options: [.allowBluetooth, .allowBluetoothA2DP])
        //try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .allowBluetoothA2DP)
        try! audioSession.setActive(true)
    }
    
    class func speak(_ words: String?){
        synthesizer.delegate = delegate
        if let speechText = words {
            stopSpeakingUtterance()
            let utterance = AVSpeechUtterance(string: speechText)
            utterance.rate = rate
            utterance.volume = 1.0
            utterance.voice = voice
            self._init_audio_session()
            synthesizer.speak(utterance)
        }
    }
    
    class func speak(_ words: String?, wait: Bool = false, callback: (() -> Void)?) {
        if !wait && synthesizer.isSpeaking {
            stopSpeakingUtterance()
        }
        
        synthesizer.delegate = delegate
        if let speechText = words {
            stopSpeakingUtterance()
            let utterance = AVSpeechUtterance(string: speechText)
            utterance.rate = rate
            utterance.volume = 1.0
            utterance.voice = voice
            
            delegate.map[speechText] = callback
            self._init_audio_session()
            synthesizer.speak(utterance)
        } else {
            callback?()
        }
    }
}

class SilverDefaultTTS: TTSProtocol {
    func stop(_ immediate: Bool) {
        Synthesizer.stopSpeakingUtterance()
    }
    
    func vibrate() {
        //nop
    }
    
    func playVoiceRecoStart() {
        //nop
    }
    
    let delegate:DialogViewHelper

    init(delegate:DialogViewHelper, _langid:String, _criteria:[NSRegularExpression]? = nil){
        self.delegate = delegate
        self.setlang(_langid)
        if let criteria = _criteria{
            self.setByName(criteria)
        }
    }
    func setlang(_ langid:String){
        Synthesizer.setLanguege(langid)
    }
    func setrate(_ relative:Float){
        Synthesizer.setRate(val: relative)
    }
    func setByName(_ criteria:[NSRegularExpression]){
        Synthesizer.searchPreferredVoice(criteria)
    }
    func speak(_ text: String?, callback: @escaping () -> Void) {
        self.delegate.speak()
        self.delegate.showText(" ")
        Synthesizer.speak(text, callback: callback)
    }
    func stop() {
        Synthesizer.stopSpeakingUtterance()
    }
}
