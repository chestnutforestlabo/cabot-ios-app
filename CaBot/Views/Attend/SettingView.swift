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

    var body: some View {
        return Form {
            Section(header: Text("Settings")){
                Button(action: {
                    UserDefaults.standard.setValue(false, forKey: ResourceSelectView.resourceSelectedKey)
                    UserDefaults.standard.synchronize()
                    modelData.displayedScene = .ResourceSelect
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("SELECT_RESOURCE")
                }

                if let resource = modelData.resource {
                    Picker("LANGUAGE", selection: $langOverride) {
                        ForEach(resource.languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }.onChange(of: langOverride) { lang in
                        modelData.resource?.lang = lang
                        self.isResourceChanging = true
                        modelData.resource = modelData.resource
                        modelData.updateVoice()
                        modelData.share(user_info: SharedInfo(type: .ChangeLanguage, value: lang))
                    }
                }

                NavigationLink(destination: DetailSettingView().environmentObject(modelData.detailSettingModel), label: {
                    Text("DETAIL_SETTING")
                })
            }

            Section(header:Text("TTS")) {
                Toggle(isOn: $modelData.isTTSEnabledForAdvanced) {
                    Text("TTS Enabled (Advanced only)")
                }
                Toggle(isOn: $modelData.isTTSUserSync) {
                    Text("Sync Voice Settings")
                }
                if(!modelData.isTTSUserSync){
                    Picker(LocalizedStringKey("Voice"), selection: $modelData.voice) {
                        ForEach(TTSHelper.getVoices(by: locale), id: \.self) { voice in
                            Text(voice.AVvoice.name).tag(voice as Voice?)
                        }
                    }.onChange(of: modelData.voice, perform: { value in
                        if let voice = modelData.voice {
                            if !isResourceChanging {
                                modelData.playSample()
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
                                modelData.playSample()
                            }
                        })
                        .accessibility(label: Text("Speech Speed"))
                        .accessibility(value: Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0])))
                        Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0]))
                            .accessibility(hidden: true)
                    }
                }
                
                if(modelData.isTTSUserSync){
                    Picker(LocalizedStringKey("User Voice"), selection: $modelData.voice) {
                        ForEach(TTSHelper.getVoices(by: locale), id: \.self) { voice in
                            Text(voice.AVvoice.name).tag(voice as Voice?)
                        }
                    }.onChange(of: modelData.voice, perform: { value in
                        if let voice = modelData.voice {
                            if !isResourceChanging {
                                modelData.playSample()
                            }
                        }
                    }).onTapGesture {
                        isResourceChanging = false
                    }
                    .pickerStyle(DefaultPickerStyle())
                    HStack {
                        Text("User Speech Speed")
                            .accessibility(hidden: true)
                        Slider(value: $modelData.speechRate,
                               in: 0...1,
                               step: 0.05,
                               onEditingChanged: { editing in
                                timer?.invalidate()
                                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                                    modelData.playSample()
                                }
                        })
                            .accessibility(label: Text("User Speech Speed"))
                            .accessibility(value: Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0])))
                        Text(String(format:"%.0f %%", arguments:[modelData.speechRate*100.0]))
                            .accessibility(hidden: true)
                    }
                }
            }

            Section(header: Text("Connection")) {
                VStack {
                    HStack{
                        Text("PRIORITY_CONNECTION")
                        Spacer()
                    }
                    Picker("", selection: $modelData.connectionType){
                        ForEach(ConnectionType.allCases, id: \.self){ (type) in
                            Text(type.rawValue).tag(type)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }
                HStack {
                    Text("ROBOT_NAME_LABEL")
                    TextField("ROBOT_NAME", text: $modelData.teamID)
                }
                HStack {
                    Text("PRIMARY_IP_ADDRESS")
                    TextField("PLACEHOLDER_IP_ADDRESS", text:
                                $modelData.primaryAddr
                    )
                }
                HStack {
                    Text("SECONDARY_IP_ADDRESS")
                    TextField("PLACEHOLDER_IP_ADDRESS", text:
                                $modelData.secondaryAddr)
                }
            }

            if (modelData.modeType == .Debug){
                Section(header: Text("DEBUG")) {
                    Toggle("MENU_DEBUG", isOn: $modelData.menuDebug)
                    Toggle("NO_SUITCASE_DEBUG", isOn: $modelData.noSuitcaseDebug)
                }
            }
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        preview
        preview_ja
    }
    
    static var preview: some View {
        let modelData = CaBotAppModel()
        
        modelData.teamID = "test"
        
        return SettingView(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
            .previewDisplayName("preview")
    }
    static var preview_ja: some View {
        let modelData = CaBotAppModel()
        
        modelData.teamID = "test"
        
        return SettingView(langOverride: "ja-JP")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "ja-JP"))
            .previewDisplayName("preview_ja")
    }
}

extension View {
    func print(_ value: Any) -> Self {
        Swift.print(value)
        return self
    }
}
