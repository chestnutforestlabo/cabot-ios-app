/*******************************************************************************
 * Copyright (c) 2024  Carnegie Mellon University
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
import ChatView

public struct ContentView: View {
    @EnvironmentObject var appModel: CaBotAppModel
    @StateObject var model: ChatViewModel
    @State var timer: Timer?
    static var expire_at = Date()
    public var body: some View {
        ChatView(messages: model.messages)
        HStack {
            Spacer()
            ChatStateButton(action: {
                model.toggleChat()
            }, state: $model.chatState)
            .frame(width: 150)
            Spacer()
        }
        .frame(height: 200)
        .onAppear() {
            startChat(true)
        }
        .onDisappear() {
            startChat(false)
        }
    }
    
    func startChat(_ start: Bool) {
        if !start {
            model.stt?.endRecognize()
            timer?.invalidate()
            ContentView.expire_at = Date(timeIntervalSinceNow: 10.0)
            return
        }
        var count_down = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if start, let stt: AppleSTT = model.stt {
                if stt.recognizing {
                    count_down = 5
                }
                if count_down > 0 {
                    appModel.requestCameraImage()
                    count_down -= 1
                }
            }
        }
        if model.stt == nil {
            model.stt = AppleSTT(state: $model.chatState, tts: PriorityQueueTTSWrapper.shared)
            model.chat = ChatClientOpenAI(config:model.config, callback: model.process)
        } else {
            if Date() > ContentView.expire_at {
                ChatData.shared.clear()
                model.chat?.restart(config:model.config)
                model.messages.removeAll()
            }
        }
        debugPrintTourData()
        model.send(message: "")
    }

    func debugPrintTourData() {
        if let result = try? ResourceManager.shared.load() {
            let tours = result.tours
            let destinations =  result.directory.allDestinations()
            NSLog("\(tours.count) chat tours")
            tours.forEach() { tour in
                NSLog("chat tour \(tour.title.text) \(tour.id)")
            }
            NSLog("\(destinations.count) chat destinations")
            destinations.forEach() { dest in
                NSLog("chat destination \(dest.title.text) \(dest._id)")
            }
        }
    }
}

#Preview("ChatView") {
    let model = ChatViewModel()
    model.messages = [
        ChatMessage(user: .User, text: "Hello1\nHello2\nHello3"),
        ChatMessage(user: .Agent, text: "Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2"),
        ChatMessage(user: .User, text: "Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 ")
    ]
    return ContentView(model: model)
}

#Preview("ChatView Dynamic") {
    let model = ChatViewModel()
    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
        model.messages.append(ChatMessage(user: .User, text: "Hello1\nHello2\nHello3"))
    }
    DispatchQueue.main.asyncAfter(deadline: .now()+2) {
        model.messages.append(ChatMessage(user: .Agent, text: "Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2 Hello2"))
    }
    DispatchQueue.main.asyncAfter(deadline: .now()+3) {
        model.messages.append(ChatMessage(user: .User, text: "Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 Hello3 "))
    }
    return ContentView(model: model)
}

#Preview("ChatView Streaming") {
    let model = ChatViewModel()
    let message = ChatMessage(user: .Agent, text: "")
    let long_sample: String = "This is a sample message."
    var count = 0
    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {timer in
        let text = long_sample
        if count < text.count {
            let index = text.index(text.startIndex, offsetBy: count)
            let character = text[index]
            message.append(text: String(character))
            count += 1
        } else {
            model.chatState.chatState = .Inactive
            timer.invalidate()
        }
    }
    model.messages.append(message)
    model.chatState.chatState = .Speaking
    return ContentView(model: model)
}
