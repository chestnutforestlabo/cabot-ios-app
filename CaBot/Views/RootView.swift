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

struct RootView: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        return NavigationView {
            VStack {
                switch(modelData.displayedScene) {
                case .Onboard:
                    OnboardGrantAccess()
                        .environmentObject(modelData)
                case .ResourceSelect:
                    ResourceSelectView()
                        .environmentObject(modelData)
                case .App:
                    MainMenuView()
                        .environmentObject(modelData)
                        .environment(\.locale, modelData.resource?.locale ?? .init(identifier: "base"))
                }
            }
            .navigationTitle("AI Suitcase")
            .onChange(of: modelData.suitcaseConnected) { value in
                let text = value ? NSLocalizedString("Suitcase has been connected", comment: "") :
                    NSLocalizedString("Suitcase has been disconnected", comment: "")

                UIAccessibility.post(notification: .announcement, argument: text)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if modelData.suitcaseConnected {
                        if modelData.backpackConnected {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .accessibility(label: Text("Suitcase and Backpack Connected"))
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .accessibility(label: Text("Suitcase Connected"))
                        }
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .opacity(0.1)
                            .accessibility(label: Text("Suitcase Not Connected"))

                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {

                    if modelData.displayedScene == .App {
                        NavigationLink (destination: SettingView()
                                            .environmentObject(modelData)
                                            .environment(\.locale, modelData.resource?.locale ?? .init(identifier: "base"))) {
                            HStack {
                                Text("")
                                    .accessibilityHidden(true)

                                Image(systemName: "gearshape")
                                    .accessibilityElement()
                                    .accessibility(label: Text("Settings"))
                                    .frame(width: 30, height: 30, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        previewSelect
        previewApp
        preview
    }

    static var preview: some View {
        let modelData = CaBotAppModel()
        modelData.suitcaseConnected = false
        modelData.backpackConnected = false

        return RootView()
            .environmentObject(modelData)
    }

    static var previewSelect: some View {
        let modelData = CaBotAppModel()
        modelData.displayedScene = .ResourceSelect
        modelData.suitcaseConnected = false
        modelData.backpackConnected = false
        modelData.resource = nil

        return RootView()
            .environmentObject(modelData)
    }

    static var previewApp: some View {
        let modelData = CaBotAppModel()
        modelData.displayedScene = .App
        modelData.suitcaseConnected = false
        modelData.backpackConnected = false
        modelData.resource = modelData.resourceManager.resource(by: "place0")

        return RootView()
            .environmentObject(modelData)
    }
}
