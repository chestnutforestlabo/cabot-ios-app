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
            Text("ONBOARD_MESSAGE")
                .padding()

            Button(action: {
                userAction = true
                modelData.requestLocationAuthorization()
            }) {
                switch(modelData.locationState) {
                case .Init:
                    Label(NSLocalizedString("Enable Location Update", comment: ""), systemImage:"circle")
                case .Granted:
                    Label(NSLocalizedString("Location Update Enabled", comment: ""), systemImage:"checkmark.circle")
                case .Denied:
                    Label(NSLocalizedString("Location Update Denied", comment: ""), systemImage:"multiply.circle")
                case .Off:
                    Label(NSLocalizedString("ERROR", comment: ""), systemImage:"multiply.circle")
                }
            }
            .padding()
            .disabled(modelData.locationState != .Init)
            .frame(width:250, alignment: .leading)

            Button(action: {
                userAction = true
                modelData.requestBluetoothAuthorization()
            }) {
                switch(modelData.bluetoothState) {
                case .unknown:
                    Label(NSLocalizedString("Enable Bluetooth", comment: ""), systemImage: "circle")
                case .unauthorized:
                    Label(NSLocalizedString("Bluetooth Denied", comment: ""), systemImage: "multiply.circle")
                case .poweredOn:
                    Label(NSLocalizedString("Bluetooth Enabled", comment: ""), systemImage: "checkmark.circle")
                case .poweredOff:
                    Label(NSLocalizedString("Bluetooth is Off", comment: ""), systemImage: "circle")
                case .unsupported:
                    Label(NSLocalizedString("Running on Simulator?", comment: ""),
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
                modelData.requestNotificationAuthorization()
            }) {
                switch(modelData.notificationState) {
                case .Init:
                    Label(NSLocalizedString("Enable Notification", comment: ""), systemImage:"circle")
                case .Granted:
                    Label(NSLocalizedString("Notification Enabled", comment: ""), systemImage:"checkmark.circle")
                case .Denied:
                    Label(NSLocalizedString("Notification Denied", comment: ""), systemImage:"multiply.circle")
                case .Off:
                    Label(NSLocalizedString("ERROR", comment: ""), systemImage:"multiply.circle")
                }
            }
            .padding()
            .disabled(modelData.notificationState != .Init)
            .frame(width:250, alignment: .leading)
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
