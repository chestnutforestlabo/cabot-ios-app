/*******************************************************************************
 * Copyright (c) 2024  IBM Corporation and Carnegie Mellon University
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

struct ChatSettingsView: View {
    @EnvironmentObject var model: CaBotAppModel


    var body: some View {
        Form {
            Section("Chat server connection") {
                VStack(alignment:.leading) {
                    Text("Host:")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Host name", text: $model.chatModel.config.host)
                        .autocapitalization(.none)
                        .keyboardType(.asciiCapable)
                }
                VStack(alignment:.leading) {
                    Text("Api Key:")
                        .font(.caption).foregroundColor(.secondary)
                    SecureField("", text: $model.chatModel.config.apiKey)
                        .autocapitalization(.none)
                        .keyboardType(.asciiCapable)
                }
            }
            Section("For development use only") {
                VStack(alignment:.leading) {
                    Text("Time to reset chat session when inactive")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Slider(value: $model.chatModel.inactive_delay, in: 10...300, step: 5)
                        Text(LocalizedStringKey("\(model.chatModel.inactive_delay, specifier: "%.1f") sec"))
                    }
                }
            }
        }.navigationTitle(Text("Settings"))
    }
}

#Preview {
    let model = CaBotAppModel(preview: true)
    return ChatSettingsView().environmentObject(model)
}
