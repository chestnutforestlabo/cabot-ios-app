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

struct BatteryStatusView: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        return VStack {
            Form {
                Section(header:Text("Status")) {
                    Text(LocalizedStringKey(modelData.batteryStatus.message))
                }

                Section(header:Text("Details")) {
                    List {
                        ForEach (modelData.batteryStatus.details.keys, id: \.self) {key in
                            if let detail = modelData.batteryStatus.details[key] {
                                HStack {
                                    Text(key)
                                        .frame(maxWidth: nil, alignment: .topLeading)
                                    Text(detail)
                                        .frame(maxWidth: nil, alignment: .topLeading)
                                }
                            }
                        }
                    }
                }

            }
            .navigationTitle("Battery Status")
        }
    }
}

struct BatteryStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()
        modelData.suitcaseConnected = true
        modelData.batteryStatus = BatteryStatus()

        return DeviceStatusView()
            .environmentObject(modelData)
    }
}
