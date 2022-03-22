// please remove this line
/*******************************************************************************
 * Copyright (c) 2022  Carnegie Mellon University
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

struct DeviceStatusView: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State private var isConfirmingReboot = false
    @State private var isConfirmingPoweroff = false
    var body: some View {
        return VStack {
            Form {
                Section(header:Text("Details")) {
                    List {
                        ForEach (modelData.deviceStatus.devices, id: \.self) {device in
                            VStack(alignment: .leading) {
                                Label(device.name, systemImage: device.level.icon)
                                    .labelStyle(StatusLabelStyle(color: device.level.color))
                                Label(device.message, systemImage: "text.bubble")
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                }

                if (modelData.adminMode) {
                    Section(header:Text("Actions")) {
                        Button(action: {
                            isConfirmingReboot = true
                        }) {
                            Text("Reboot")
                                .frame(width: nil, alignment: .topLeading)
                        }
                        .actionSheet(isPresented: $isConfirmingReboot) {
                            return ActionSheet(title: Text("Reboot Computer"),
                                               message: Text("The app will be disconnected."),
                                               buttons: [
                                                .cancel(),
                                                .destructive(
                                                    Text("Reboot"),
                                                    action: {
                                                        modelData.systemManageCommand(command: .reboot)
                                                    }
                                                )
                                               ])
                        }

                        Button(action: {
                            isConfirmingPoweroff = true
                        }) {
                            Text("Power off")
                                .frame(width: nil, alignment: .topLeading)
                        }
                        .actionSheet(isPresented: $isConfirmingPoweroff) {
                            return ActionSheet(title: Text("Power off"),
                                               message: Text("The app will be disconnected."),
                                               buttons: [
                                                .cancel(),
                                                .destructive(
                                                    Text("Power off"),
                                                    action: {
                                                        modelData.systemManageCommand(command: .poweroff)
                                                    }
                                                )
                                               ])
                        }

                    }
                }
            }
            .navigationTitle("Device Status")
        }
    }
}

struct DeviceStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()
        modelData.suitcaseConnected = true
        let path = Bundle.main.resourceURL!.appendingPathComponent("PreviewResource")
            .appendingPathComponent("device.json")

        let fm = FileManager.default
        let data = fm.contents(atPath: path.path)!
        do {
            let status = try JSONDecoder().decode(DeviceStatus.self, from: data)
            modelData.deviceStatus = status
        } catch {
            modelData.deviceStatus.devices = []
            modelData.deviceStatus.devices.append(DeviceStatusEntry(name: "Test", level: .Error, message: "Error", values:[]))
        }

        return DeviceStatusView()
            .environmentObject(modelData)
    }
}
