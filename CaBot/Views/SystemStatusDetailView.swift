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

struct SystemStatusDetailView: View {
    @EnvironmentObject var modelData: CaBotAppModel
    let key: String

    var body: some View {
        let status = modelData.systemStatus.components[key]!
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach (status.details.keys, id:\.self) {key2 in
                    let diagnostic = status.details[key2]!
                    DiagnosticCell(key: key, key2: key2)
                        .environmentObject(modelData)
                        .animation(.default)
                }
            }
        }
    }
    private var header: some View {
        let status = modelData.systemStatus.components[key]!
        return HStack {
            Label(status.name, systemImage: status.level.icon)
            Text(":")
            Text(status.message)
        }
        .padding(.leading)
    }
}

struct DiagnosticCell: View {
    @EnvironmentObject var modelData: CaBotAppModel
    let key: String
    let key2: String
    @State private var isExpanded: Bool = true

    var body: some View {
        content
            .padding(.leading)
            .frame(maxWidth: .infinity)
    }

    private var content: some View {
        let diagnostic = modelData.systemStatus.components[key]!.details[key2]!
        return VStack(alignment: .leading, spacing: 8) {
            header
            if isExpanded {
                Group {
                    ForEach(diagnostic.values.keys, id:\.self) { key in
                        let value = diagnostic.values[key]!
                        HStack (alignment: .top) {
                            Text(key)
                                .frame(width: 200, alignment: .topLeading)
                            Text(":")
                            Text(value)
                        }
                        .frame(alignment: .top)
                    }
                }
                .padding(.leading)
            }
            Divider()
        }
    }

    private var header: some View {
        let diagnostic = modelData.systemStatus.components[key]!.details[key2]!
        return VStack {
            Label(diagnostic.name, systemImage: diagnostic.level.icon)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Label(diagnostic.message, systemImage: "text.bubble")
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.vertical, 4)
        .onTapGesture { isExpanded.toggle() }
    }
}

struct SystemStatusDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let model:CaBotAppModel = CaBotAppModel()
        let modelData = CaBotAppModel()
        modelData.suitcaseConnected = true
        let path = Bundle.main.resourceURL!.appendingPathComponent("PreviewResource")
            .appendingPathComponent("system.json")

        let fm = FileManager.default
        let data = fm.contents(atPath: path.path)!
        let status = try! JSONDecoder().decode(SystemStatus.self, from: data)
        modelData.systemStatus.update(with: status)

        return SystemStatusDetailView(key: "Hard: Handle")
            .environmentObject(modelData)
    }
}
