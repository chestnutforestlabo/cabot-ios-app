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
import CoreBluetooth
import UserNotifications


struct OnboardGrantAccess: View {
    @EnvironmentObject var modelData:CaBotAppModel

    @State var userAction: Bool = false

    var body: some View {

        return VStack {
            Text("Please allow the app to access the Bluetooth device to connect to the scale and use notification.")
                .padding()

            Button(action: {
                userAction = true
                modelData.service.start()
                modelData.service.startAdvertising()
            }) {
                switch(modelData.bluetoothState) {
                case .unknown:
                    Label("Enable Bluetooth", systemImage: "circle")
                case .unauthorized:
                    Label("Bluetooth Denied", systemImage: "multiply.circle")
                case .poweredOn:
                    Label("Bluetooth Enabled", systemImage: "checkmark.circle")
                case .poweredOff:
                    Label("Bluetooth is Off", systemImage: "circle")
                case .unsupported:
                    Label("Running on Simulator?",
                          systemImage: "multiply.circle")
                default:
                    Text("bluetoothState error")
                }
            }
            .padding()
            .disabled(modelData.bluetoothState != .unknown)
            .frame(width:250, alignment: .leading)

            Button(action: {
                userAction = true
                let center = UNUserNotificationCenter.current()

                center.requestAuthorization(options:[UNAuthorizationOptions.alert,
                                                     UNAuthorizationOptions.sound]) {
                    (granted, error) in
                    DispatchQueue.main.async {
                        modelData.notificationState = granted ? .Granted : .Denied
                    }
                }
            }) {
                switch(modelData.notificationState) {
                case .Init:
                    Label("Enable Notification", systemImage:"circle")
                case .Granted:
                    Label("Notification Enabled", systemImage:"checkmark.circle")
                case .Denied:
                    Label("Notification Denied", systemImage:"multiply.circle")
                case .Off:
                    Label("ERROR", systemImage:"multiply.circle")
                }
            }
            .padding()
            .disabled(modelData.notificationState != .Init)
            .frame(width:250, alignment: .leading)

            /*
            HStack {
                Spacer()
                Button("Next") {
                    modelData.displayedScene = .ResourceSelect
                }
                .padding()
                .disabled(modelData.bluetoothState != .poweredOn ||
             modelData.notificationState == .Init)
            }
 */
        }
        .onChange(of: modelData.bluetoothState, perform: { value in
            checkCondition()
        })
        .onChange(of: modelData.notificationState, perform: { value in
            checkCondition()
        })
        .onAppear(perform: {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.alertSetting == .enabled &&
                        settings.soundSetting == .enabled {
                        modelData.notificationState = .Granted
                    } else {
                    }
                }
            }
        })
    }

    func checkCondition() {
        if modelData.bluetoothState == .poweredOn &&
            modelData.notificationState != .Init {
            if userAction {
                withAnimation() {
                    modelData.displayedScene = .ResourceSelect
                }
            } else {
                modelData.displayedScene = .ResourceSelect
            }
        }
    }
}

struct OnboardGrantAccess_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        OnboardGrantAccess()
            .environmentObject(modelData)
            .previewDevice("iPhone 12 Pro")
            .previewDisplayName("Normal")
    }
}
