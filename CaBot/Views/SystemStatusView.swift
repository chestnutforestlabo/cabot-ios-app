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

struct SystemStatusView: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State private var isConfirmingStart = false
    @State private var isConfirmingStop = false

    var body: some View {
        var isServiceActive:Bool = false
        if let service = modelData.systemStatusDetail["Service"] {
            isServiceActive = service.status
        }

        return NavigationView {
            VStack {
                Form {
                    Section(header:Text("Status")) {
                        Text(LocalizedStringKey(modelData.systemStatus.rawValue))
                    }

                    Section(header:Text("Details")) {
                        List {
                            ForEach (modelData.systemStatusDetail.keys, id: \.self) {key in
                                VStack {
                                    Text(modelData.systemStatusDetail[key]!.text)
                                        .frame(maxWidth: nil, alignment: .topLeading)
                                }
                            }
                        }
                    }

                    if (modelData.adminMode) {
                        Section(header:Text("Actions")) {
                            Button(action: {
                                isConfirmingStart = true
                            }) {
                                Text("Start")
                                    .frame(width: nil, alignment: .topLeading)
                            }
                            .actionSheet(isPresented: $isConfirmingStart) {
                                return ActionSheet(title: Text("Start System"),
                                                   message: Text("Start CaBot ROS system"),
                                                   buttons: [
                                                    .cancel(),
                                                    .destructive(
                                                        Text("Start"),
                                                        action: {
                                                            modelData.systemManageCommand(command: .start)
                                                        }
                                                    )
                                                   ])
                            }
                            .disabled(isServiceActive)

                            Button(action: {
                                isConfirmingStop = true
                            }) {
                                Text("Stop")
                                    .frame(width: .infinity, alignment: .topLeading)
                            }
                            .actionSheet(isPresented: $isConfirmingStop) {
                                return ActionSheet(title: Text("Stop System"),
                                                   message: Text("Stop CaBot ROS system"),
                                                   buttons: [
                                                    .cancel(),
                                                    .destructive(
                                                        Text("Stop"),
                                                        action: {
                                                            modelData.systemManageCommand(command: .stop)
                                                        }
                                                    )
                                                   ])
                            }
                            .disabled(!isServiceActive)
                        }
                    }
                }
            }
            .navigationTitle("System Status")
        }
    }
}

struct SystemStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()
        modelData.suitcaseConnected = true
        modelData.systemStatus = .NG
        modelData.systemStatusDetail["Service"] = StatusEntry(name: "Service", status: true, message: "dummy")
        return SystemStatusView()
            .environmentObject(modelData)
    }
}
