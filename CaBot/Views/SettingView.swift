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

import SwiftUI

struct SettingView: View {
    @Environment(\.locale) var locale: Locale
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    @State var timer:Timer?
    @State var langOverride:String
    @State var isResourceChanging:Bool = false

    let startSounds:[String] = [
        "/System/Library/Audio/UISounds/nano/3rdParty_Success_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/3rdParty_Start_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/Alert_SpartanConnecting_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/Warsaw_Haptic.caf",
    ]
    let arrivedSounds:[String] = [
        "/System/Library/Audio/UISounds/nano/HummingbirdNotification_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/Alarm_Nightstand_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/WorkoutStartAutodetect.caf",
        "/System/Library/Audio/UISounds/nano/Alert_MapsDirectionsInApp_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/WorkoutSaved_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/MultiwayInvitation.caf",
        "/System/Library/Audio/UISounds/nano/SiriStopSuccess_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/NavigationGenericManeuver_Haptic.caf",
    ]
    let speedUpSounds:[String] = [
        "/System/Library/Audio/UISounds/nano/WalkieTalkieActiveStart_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/3rdParty_DirectionUp_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/WalkieTalkieReceiveStart_Haptic.caf",
    ]
    let speedDownSounds:[String] = [
        "/System/Library/Audio/UISounds/nano/ET_RemoteTap_Receive_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/3rdParty_DirectionDown_Haptic.caf",
        "/System/Library/Audio/UISounds/nano/WalkieTalkieReceiveEnd_Haptic.caf",
    ]

    var body: some View {
        return Form {
            Section(header: Text("Speech Voice")) {
                Picker(LocalizedStringKey("Voice"), selection: $modelData.voice) {
                    ForEach(TTSHelper.getVoices(by: locale), id: \.self) { voice in
                        Text(voice.AVvoice.name).tag(voice as Voice?)
                    }
                }.onChange(of: modelData.voice, perform: { value in
                    if let voice = modelData.voice {
                        if !isResourceChanging {
                            TTSHelper.playSample(of: voice)
                        }
                    }
                }).onTapGesture {
                    isResourceChanging = false
                }
                .pickerStyle(DefaultPickerStyle())

                HStack {
                    Text("Speech Speed")
                        .accessibility(hidden: true)
                    Slider(value: $modelData.speechRate,
                           in: 0...1,
                           step: 0.05,
                           onEditingChanged: { editing in
                            timer?.invalidate()
                            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                                TTSHelper.playSample(of: modelData.voice!, at: modelData.speechRate)
                            }
                    })
                        .accessibility(label: Text("Speech Speed"))
                        .accessibility(value: Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0])))
                    Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0]))
                        .accessibility(hidden: true)
                }
            }
            Section(header: Text("Audio Effect")) {
                Picker("Start", selection: $modelData.startSound) {
                    ForEach(startSounds, id: \.self) { sound in
                        Text(NSString(string: sound).lastPathComponent).tag(sound)
                    }
                }.onChange(of: modelData.startSound) { value in
                    modelData.playAudio(file: value)
                }
                Picker("Arrived", selection: $modelData.arrivedSound) {
                    ForEach(arrivedSounds, id: \.self) { sound in
                        Text(NSString(string: sound).lastPathComponent).tag(sound)
                    }
                }.onChange(of: modelData.arrivedSound) { value in
                    modelData.playAudio(file: value)
                }
                Picker("SpeedUp", selection: $modelData.speedUpSound) {
                    ForEach(speedUpSounds, id: \.self) { sound in
                        Text(NSString(string: sound).lastPathComponent).tag(sound)
                    }
                }.onChange(of: modelData.speedUpSound) { value in
                    modelData.playAudio(file: value)
                }
                Picker("SpeedDown", selection: $modelData.speedDownSound) {
                    ForEach(speedDownSounds, id: \.self) { sound in
                        Text(NSString(string: sound).lastPathComponent).tag(sound)
                    }
                }.onChange(of: modelData.speedDownSound) { value in
                    modelData.playAudio(file: value)
                }
            }
            Section(header: Text("Connection")) {
                Picker("", selection: $modelData.connectionType){
                    ForEach(ConnectionType.allCases, id: \.self){ (type) in
                        Text(type.rawValue).tag(type)
                    }
                }.pickerStyle(SegmentedPickerStyle())
                if modelData.connectionType == ConnectionType.BLE{
                    HStack {
                        Text("Team ID(ble)")
                        TextField("Team ID", text: $modelData.teamID)
                    }
                }else{
                    HStack {
                        Text("Socket Address")
                        TextField("Socket Address", text:
                                    $modelData.socketAddr)
                    }
                }
            }
            Section(header: Text("VoiceOver adjustment")) {
                VStack {
                    Text("Delay after closing browser")
                        .accessibility(hidden: true)
                    HStack {
                        Slider(value: $modelData.browserCloseDelay,
                               in: 1...2,
                               step: 0.1)
                            .accessibility(label: Text("Delay after closing browser"))
                            .accessibility(value: Text(LocalizedStringKey("\(modelData.browserCloseDelay, specifier: "%.1f") seconds")))
                        Text(LocalizedStringKey("\(modelData.browserCloseDelay, specifier: "%.1f") sec"))
                            .accessibility(hidden: true)
                    }
                }
            }

            Section(header: Text("Others")) {
                Button(action: {
                    UserDefaults.standard.setValue(false, forKey: ResourceSelectView.resourceSelectedKey)
                    UserDefaults.standard.synchronize()
                    modelData.displayedScene = .ResourceSelect
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("SELECT_RESOURCE")
                }

                if let resource = modelData.resource {
                    Picker("Language", selection: $langOverride) {
                        ForEach(resource.languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }.onChange(of: langOverride) { lang in
                        modelData.resource?.lang = lang
                        self.isResourceChanging = true
                        modelData.resource = modelData.resource
                    }
                }

                Toggle("Menu Debug", isOn: $modelData.menuDebug)
                Toggle("No Suitcase Debug", isOn: $modelData.noSuitcaseDebug)
            }
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resource(by: "place0")!

        modelData.resource = resource
        modelData.teamID = "test"

        return SettingView(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}

extension View {
    func print(_ value: Any) -> Self {
        Swift.print(value)
        return self
    }
}
