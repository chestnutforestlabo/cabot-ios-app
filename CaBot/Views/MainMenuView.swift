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
import CoreData

struct MainMenuView: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        Form {
            if modelData.noSuitcaseDebug {
                Label("No Suitcase Debug mode", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
            if hasAnyAction() {
                ActionMenus()
                    .environmentObject(modelData)
            }
            DestinationMenus()
                .environmentObject(modelData)
            MainMenus()
                .environmentObject(modelData)
                .disabled(!modelData.suitcaseConnected && !modelData.menuDebug)
            StatusMenus()
                .environmentObject(modelData)
            MapMenus()
                .environmentObject(modelData)
            SettingMenus()
                .environmentObject(modelData)
        }
    }

    func hasAnyAction() -> Bool {
        if modelData.tourManager.hasDestination && modelData.menuDebug {
            return true
        }
        if let ad = modelData.tourManager.arrivedDestination {
            if let _ = ad.content?.url {
                return true
            }
            if modelData.tourManager.currentDestination == nil,
               let _ = ad.waitingDestination?.value,
               let _ = ad.waitingDestination?.title {
                return true
            }
        }
        return false
    }
}

struct ActionMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel
    
    var body: some View {
        Section(header: Text("Actions")) {
            if modelData.tourManager.hasDestination && modelData.menuDebug {
                if let _ = modelData.tourManager.currentDestination {
                    Button(action: {
                        modelData.tourManager.stopCurrent()
                    }) {
                        Text("PAUSE_NAVIGATION")
                    }
                    .disabled(!modelData.suitcaseConnected)
                } else if modelData.tourManager.destinations.count > 0 {
                    Button(action: {
                        _ = modelData.tourManager.proceedToNextDestination()
                    }) {
                        Label{
                            Text("START")
                        } icon: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        }
                    }
                    .disabled(!modelData.suitcaseConnected)
                }
            }
            
            ArrivedActionMenus()
                .environmentObject(modelData)
        }
    }
}


struct ArrivedActionMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel
    
    var body: some View {
        if let ad = modelData.tourManager.arrivedDestination {
            if let contentURL = ad.content?.url {
                Button(action: {
                    modelData.open(content: contentURL)
                }) {
                    Label(title: {
                        Text("Open Content for \(ad.title.text)")
                    }, icon: {
                        Image(systemName: "newspaper")
                    })
                }
            }
            if modelData.tourManager.currentDestination == nil,
               let _ = ad.waitingDestination?.value,
               let title = ad.waitingDestination?.title {
                Button(action: {
                    modelData.isConfirmingSummons = true
                }) {
                    Label(title: {
                        Text("Let the suitcase wait at \(title.text)")
                    }, icon: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    })
                }
                .disabled(!modelData.suitcaseConnected && !modelData.menuDebug)
            }
            if let count = ad.arriveMessages?.count {
                if let text = ad.arriveMessages?[count-1].content {
                    Button(action: {
                        modelData.speak(text) {}
                    }) {
                        Label{
                            Text("Repeat the message")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            if let subtour = ad.subtour {
                Button(action: {
                    modelData.addSubTour(tour: subtour)
                }) {
                    Label{
                        Text("Begin Subtour \(subtour.introduction.text)")
                    } icon: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                }
            }
            if modelData.tourManager.isSubtour {
                Button(action: {
                    modelData.tourManager.clearSubTour()
                }) {
                    Label{
                        Text("End Subtour")
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                }
            }
        }

        if modelData.tourManager.currentDestination == nil &&
            modelData.tourManager.hasDestination {
            if let next = modelData.tourManager.nextDestination {
                Button(action: {
                    modelData.skipDestination()
                }) {
                    Label{
                        Text("Skip Label \(next.title.text)")
                    } icon: {
                        Image(systemName: "arrow.right.to.line")
                    }
                }
                .disabled(!modelData.suitcaseConnected)
            }
        }
    }
}

struct DestinationMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State private var isConfirming = false

    var body: some View {
        let maxDestinationNumber = 2 + (modelData.tourManager.currentDestination==nil ? 1 : 0)

        if modelData.tourManager.hasDestination {
            Section(header: Text("Destinations")) {

                if let cd = modelData.tourManager.currentDestination {
                    HStack {
                        Label(cd.title.text,
                              systemImage: "arrow.triangle.turn.up.right.diamond")
                        .accessibilityLabel(Text("Navigating to \(cd.title.text)"))
                        if modelData.menuDebug {
                            Spacer()
                            Button(action: {
                                isConfirming = true
                            }) {
                                Image(systemName: "checkmark.seal")
                            }
                            .actionSheet(isPresented: $isConfirming) {
                                return ActionSheet(title: Text("Complete Destination"),
                                                   message: Text("Complete Destination Message"),
                                                   buttons: [
                                                    .cancel(),
                                                    .destructive(
                                                        Text("Complete Destination"),
                                                        action: {
                                                            modelData.debugCabotArrived()
                                                        }
                                                    )
                                                   ])
                            }
                        }
                    }
                }
                ForEach(modelData.tourManager.first(n: maxDestinationNumber-1), id: \.self) {dest in
                    Label(dest.title.text, systemImage: "mappin.and.ellipse")
                }
                if modelData.tourManager.destinations.count > 0 {
                    NavigationLink(
                        destination: DynamicTourDetailView(tour: modelData.tourManager),
                        label: {
                            HStack {
                                Spacer()
                                Text("See detail")
                            }
                        })
                }
            }
        }
    }
}

struct MainMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        if let cm = modelData.resource {
            Section(header: Text("Navigation")) {
                if let src = cm.conversationSource{
                    NavigationLink(
                        destination: ConversationView(src: src, dsrc: cm.destinationAllSource)
                            .onDisappear(){
                                modelData.resetAudioSession()
                            }
                            .environmentObject(modelData),
                        label: {
                            Text("START_CONVERSATION")
                        })
                }
                if let src = cm.destinationsSource {
                    NavigationLink(
                        destination: DestinationsView(src: src)
                            .environmentObject(modelData),
                        label: {
                            Text("SELECT_DESTINATION")
                        })
                }
                if let src = cm.toursSource {
                    NavigationLink(
                        destination: ToursView(src: src)
                            .environmentObject(modelData),
                        label: {
                            Text("SELECT_TOUR")
                        })
                }
            }


            if cm.customeMenus.count > 0 {
                Section(header: Text("Others")) {
                    ForEach (cm.customeMenus, id: \.self) {
                        menu in

                        if let url = menu.script.url {
                            Button(menu.title) {
                                let jsHelper = JSHelper(withScript: url)
                                _ = jsHelper.call(menu.function, withArguments: [])
                            }
                        }
                    }
                }
            }
        }
    }
}


struct StatusMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        Section(header:Text("Status")) {
            if modelData.modeType == .Debug{
                HStack {
                    if modelData.suitcaseConnectedBLE {
                        Label(LocalizedStringKey("BLE Connected"),
                              systemImage: "antenna.radiowaves.left.and.right")
                        if let version = modelData.serverBLEVersion {
                            Text("(\(version))")
                        }
                    } else {
                        Label(LocalizedStringKey("BLE Not Connected"),
                              systemImage: "antenna.radiowaves.left.and.right")
                        .opacity(0.1)
                    }
                }
                HStack {
                    if modelData.suitcaseConnectedTCP {
                        Label(LocalizedStringKey("TCP Connected"),
                              systemImage: "antenna.radiowaves.left.and.right")
                        if let version = modelData.serverTCPVersion {
                            Text("(\(version))")
                        }
                    } else {
                        Label(LocalizedStringKey("TCP Not Connected"),
                              systemImage: "antenna.radiowaves.left.and.right")
                            .opacity(0.1)
                    }
                }
            }else{
                if modelData.suitcaseConnected{
                    Label(LocalizedStringKey("Suitcase Connected"),
                          systemImage: "antenna.radiowaves.left.and.right")
                }else{
                    Label(LocalizedStringKey("Suitcase Not Connected"),
                          systemImage: "antenna.radiowaves.left.and.right")
                    .opacity(0.1)
                }
            }
            if modelData.suitcaseConnected {
                if (modelData.suitcaseConnectedBLE && modelData.versionMatchedBLE == false) ||
                (modelData.suitcaseConnectedTCP && modelData.versionMatchedTCP == false) {
                    Label(LocalizedStringKey("Protocol mismatch \(CaBotServiceBLE.CABOT_BLE_VERSION)"),
                          systemImage: "exclamationmark.triangle")
                        .foregroundColor(Color.red)
                }
                NavigationLink(
                    destination: BatteryStatusView().environmentObject(modelData),
                    label: {
                        HStack {
                            Label(LocalizedStringKey("Battery"),
                                  systemImage: modelData.batteryStatus.level.icon)
                                .labelStyle(StatusLabelStyle(color: modelData.batteryStatus.level.color))
                            Text(":")
                            Text(modelData.batteryStatus.message)
                        }
                    }
                ).isDetailLink(false)
                if (modelData.modeType == .Advanced || modelData.modeType == .Debug) {
                    NavigationLink(
                        destination: DeviceStatusView().environmentObject(modelData),
                        label: {
                            HStack {
                                Label(LocalizedStringKey("Device"),
                                      systemImage: modelData.deviceStatus.level.icon)
                                .labelStyle(StatusLabelStyle(color: modelData.deviceStatus.level.color))
                                Text(":")
                                Text(LocalizedStringKey(modelData.deviceStatus.level.rawValue))
                            }
                        }
                    ).isDetailLink(false)
                    NavigationLink(
                        destination: SystemStatusView().environmentObject(modelData),
                        label: {
                            HStack {
                                Label(LocalizedStringKey("System"),
                                      systemImage: modelData.systemStatus.summary.icon)
                                .labelStyle(StatusLabelStyle(color: modelData.systemStatus.summary.color))
                                Text(":")
                                Text(LocalizedStringKey(modelData.systemStatus.levelText()))
                                Text("-")
                                Text(LocalizedStringKey(modelData.systemStatus.summary.text))
                            }
                        }
                    ).isDetailLink(false)
                }
            }
        }
    }
}

struct MapMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        if modelData.modeType == .Advanced || modelData.modeType == .Debug{
            Section(header:Text("Map")) {
                HStack {
                    NavigationLink(
                        destination: RosWebView(primaryAddr: modelData.primaryAddr,
                                                secondaryAddr: modelData.secondaryAddr,
                                                port: modelData.rosPort),
                        label: {
                            Text("ROS Map")
                        })
                }
            }
        }
    }
}

struct SettingMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @Environment(\.locale) var locale: Locale
    
    @State var timer:Timer?
    @State var isResourceChanging:Bool = false
    
    var body: some View {
        let versionNo = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let buildNo = Bundle.main.infoDictionary!["CFBundleVersion"] as! String

        Section(header:Text("System")) {
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
            if (modelData.modeType == .Advanced || modelData.modeType == .Debug) {
                NavigationLink (destination: SettingView(langOverride: modelData.resourceLang)
                    .environmentObject(modelData)
                    .onDisappear {
                        modelData.tcpServiceRestart()
                    }
                ) {
                    HStack {
                        Label(LocalizedStringKey("Settings"), systemImage: "gearshape")
                    }
                }
            }
            VStack {
                HStack{
                    Text("MODE_TYPE").onTapGesture(count: 5) {
                        if (modelData.modeType != .Debug){
                            modelData.modeType = .Debug
                        }
                    }
                    Spacer()
                }
                Picker("", selection: $modelData.modeType){
                    Text(LocalizedStringKey(ModeType.Normal.rawValue)).tag(ModeType.Normal)
                    Text(LocalizedStringKey(ModeType.Advanced.rawValue)).tag(ModeType.Advanced)
                    if(modelData.modeType == .Debug){
                        Text(LocalizedStringKey(ModeType.Debug.rawValue)).tag(ModeType.Debug)
                    }
                }.pickerStyle(SegmentedPickerStyle())
            }
            Text("Version: \(versionNo) (\(buildNo)) - \(CaBotServiceBLE.CABOT_BLE_VERSION)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        preview_connected
        //preview_tour
        //preview_tour2
        //preview_tour3
        //preview_tour4
        //preview
        //preview_ja
    }

    static var preview_connected: some View {
        let modelData = CaBotAppModel()
        modelData.suitcaseConnectedBLE = true
        modelData.suitcaseConnectedTCP = true
        modelData.deviceStatus.level = .OK
        modelData.systemStatus.level = .Inactive
        modelData.systemStatus.summary = .Stale
        modelData.versionMatchedBLE = true
        modelData.versionMatchedTCP = true
        modelData.serverBLEVersion = CaBotServiceBLE.CABOT_BLE_VERSION
        modelData.serverTCPVersion = CaBotServiceBLE.CABOT_BLE_VERSION

        if let r = modelData.resourceManager.resource(by: "Test data") {
            modelData.resource = r
        }

        return MainMenuView()
            .environmentObject(modelData)
            .environment(\.locale, .init(identifier: "en"))
    }

    static var preview_tour: some View {
        let modelData = CaBotAppModel()
        modelData.menuDebug = true
        modelData.noSuitcaseDebug = true

        if let r = modelData.resourceManager.resource(by: "place0") {
            modelData.resource = r
            if let url = r.toursSource {
                if let tours = try? Tour.load(at: url) {
                    modelData.tourManager.set(tour: tours[0])
                    _ = modelData.tourManager.proceedToNextDestination()
                }
            }
        }

        return MainMenuView()
            .environmentObject(modelData)
    }

    static var preview_tour2: some View {
        let modelData = CaBotAppModel()

        if let r = modelData.resourceManager.resource(by: "place0") {
            modelData.resource = r
            if let url = r.toursSource {
                if let tours = try? Tour.load(at: url) {
                    modelData.tourManager.set(tour: tours[0])
                }
            }
        }

        return MainMenuView()
            .environmentObject(modelData)
    }

    static var preview_tour3: some View {
        let modelData = CaBotAppModel()

        if let r = modelData.resourceManager.resource(by: "place0") {
            modelData.resource = r
            if let url = r.toursSource {
                if let tours = try? Tour.load(at: url) {
                    modelData.tourManager.set(tour: tours[1])
                }
            }
        }

        return MainMenuView()
            .environmentObject(modelData)
    }

    static var preview_tour4: some View {
        let modelData = CaBotAppModel()

        if let r = modelData.resourceManager.resource(by: "place0") {
            modelData.resource = r
            if let url = r.toursSource {
                if let tours = try? Tour.load(at: url) {
                    modelData.tourManager.set(tour: tours[1])
                }
            }
        }

        return MainMenuView()
            .environmentObject(modelData)
    }

    static var preview: some View {
        let modelData = CaBotAppModel()

        modelData.resource = modelData.resourceManager.resource(by: "place0")

        return MainMenuView()
            .environmentObject(modelData)
    }


    static var preview_ja: some View {
        let modelData = CaBotAppModel()

        modelData.resource = modelData.resourceManager.resource(by: "place0")

        return MainMenuView()
            .environment(\.locale, .init(identifier: "ja"))
            .environmentObject(modelData)
    }
}
