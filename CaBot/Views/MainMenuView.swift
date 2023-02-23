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
                Label("No Suitcase Debug mode (better to restart app to connect to a suitcase)", systemImage: "exclamationmark.triangle")
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
                        _ = modelData.tourManager.nextDestination()
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

            if let ad = modelData.tourManager.arrivedDestination {
                if let contentURL = ad.content?.url {
                    Button(action: {
                        modelData.open(content: contentURL)
                    }) {
                        Label(String(format:NSLocalizedString("Open Content for %@", comment: ""), arguments: [ad.title]),
                              systemImage: "newspaper")
                    }
                }
                if modelData.tourManager.currentDestination == nil,
                   let _ = ad.waitingDestination?.value,
                   let title = ad.waitingDestination?.title {
                    Button(action: {
                        modelData.isConfirmingSummons = true
                    }) {
                        Label(String(format:NSLocalizedString("Let the suitcase wait at %@", comment: ""), arguments: [title]),
                              systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                    .disabled(!modelData.suitcaseConnected && !modelData.menuDebug)
                }
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
                        Label(cd.title,
                              systemImage: "arrow.triangle.turn.up.right.diamond")
                            .accessibilityLabel(String(format: NSLocalizedString("Navigating to %@", comment: ""),
                                                       arguments: [cd.title]))
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
                    Label(dest.title, systemImage: "mappin.and.ellipse")
                }
                if modelData.tourManager.destinations.count > 0 {
                    NavigationLink(
                        destination: TourDetailView(tour: modelData.tourManager,
                                                    showStartButton: false,
                                                    showCancelButton: true),
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
                if let url = cm.conversationURL{
                    NavigationLink(
                        destination: ConversationView(url: url)
                            .onDisappear(){
                                modelData.resetAudioSession()
                            }
                            .environmentObject(modelData),
                        label: {
                            Text("START_CONVERSATION")
                        })
                }
                if let url = cm.destinationsURL {
                    NavigationLink(
                        destination: DestinationsView(url: url)
                            .environmentObject(modelData),
                        label: {
                            Text("SELECT_DESTINATION")
                        })
                }
                if let url = cm.toursURL {
                    NavigationLink(
                        destination: ToursView(url: url)
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

struct SettingMenus: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        let versionNo = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let buildNo = Bundle.main.infoDictionary!["CFBundleVersion"] as! String

        Section(header:Text("System")) {
            NavigationLink (destination: SettingView()
                                .environmentObject(modelData)
                                .environment(\.locale, modelData.resource?.locale ?? .init(identifier: "base"))) {
                HStack {
                    Label(NSLocalizedString("Settings", comment: ""), systemImage: "gearshape")
                }
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

        if let r = modelData.resourceManager.resource(by: "place0") {
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
            if let url = r.toursURL {
                if let tours = try? Tours(at: url) {
                    modelData.tourManager.set(tour: tours.list[0])
                    _ = modelData.tourManager.nextDestination()
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
            if let url = r.toursURL {
                if let tours = try? Tours(at: url) {
                    modelData.tourManager.set(tour: tours.list[0])
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
            if let url = r.toursURL {
                if let tours = try? Tours(at: url) {
                    modelData.tourManager.set(tour: tours.list[1])
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
            if let url = r.toursURL {
                if let tours = try? Tours(at: url) {
                    modelData.tourManager.set(tour: tours.list[1])
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
