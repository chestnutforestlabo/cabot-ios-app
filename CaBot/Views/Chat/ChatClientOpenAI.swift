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

import Combine
import Foundation
import ChatView
import OpenAI

extension Model {
    static let ollama_llama3_2 = "ollama/llama3.2"
}

class ChatClientOpenAI: ChatClient {
    var callback: ChatClientCallback?
    var client: OpenAI?
    let welcome_text = "Hello"
    var pub: PassthroughSubject<String, Error>?
    var callback_called = Set<String>()
    let model: Model = .ollama_llama3_2
    var history: LimitedArray<ChatItem>
    var queryResultCancellable : AnyCancellable? = nil
    var queryResultCache :String = ""
    var metadata: [String: Any]

    init(config:ChatConfiguration, callback: @escaping ChatClientCallback) {
        self.callback = callback
        self.history = LimitedArray<ChatItem>( limit: config.historySize )
        self.metadata = [
            "conversation_id": UUID().uuidString,
            "terminal_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "suitcase_id": ChatData.shared.suitcase_id,
            "lang": I18N.shared.langCode,
            "tour_recommendation_filter": "all" // TBD
        ]
        self.initClient(config: config)
    }
    func restart(config:ChatConfiguration) {
        self.history = LimitedArray<ChatItem>( limit: config.historySize )
        self.metadata["conversation_id"] = UUID().uuidString
        self.initClient(config: config)
    }
    func initClient(config:ChatConfiguration) {
        if let url = URL(string: config.host) {
            NSLog("OpenAI Client with \(url)")
            let configuration = OpenAI.Configuration(
                token: config.apiKey,
                organizationIdentifier: nil,
                endpoint: url
            )
            self.client = OpenAI(configuration: configuration)
        } else {
            NSLog("Invalid URL \(config.host)")
            self.client = nil
        }
    }
    func send(message: String) {
        // prepare messages
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        if message.hasPrefix("data:image") {
            let vision: [ChatQuery.ChatCompletionMessageParam.ChatCompletionUserMessageParam.Content.VisionContent] =
                [.init(chatCompletionContentPartImageParam: .init(imageUrl: .init(url: message, detail: .auto)))]
            messages.append(.init(role: .user, content: vision)!)
        } else if !message.isEmpty {
            messages.append(.init(role: .user, content: message)!)
        }
        // prepare metadata
        self.metadata["request_id"] = UUID().uuidString
        if let loc = ChatData.shared.lastLocation {
            self.metadata["current_location"] = [
                "lat": loc.lat,
                "lng": loc.lng,
                "floor": loc.floor
            ]
        } else {
            self.metadata.removeValue(forKey: "current_location")
        }
        // query
        let query = ChatQuery(messages: messages, model: "dummy", metadata: AnyCodable(self.metadata))

        if let data = try? JSONEncoder().encode(query) {
            if let str = String(data: data, encoding: .utf8) {
                NSLog("chat send query: \(str)")
            }
        }

        history.append(.query(query))
        self.pub = PassthroughSubject<String, Error>()
        self.prepareSinkForHistory()
        var error_count = 0, success_count = 0
        client?.chatsStream(query: query) { partialResult in
            print("chat stream partialResult \(partialResult)")
            guard let pub = self.pub else { return }
            switch partialResult {
            case .success(let result):
                success_count += 1
                if !self.callback_called.contains(result.id) && result.choices[0].delta.toolCalls == nil {
                    self.callback?(result.id, pub)
                    self.callback_called.insert(result.id)
                }
                if let content = result.choices[0].delta.content {
                    pub.send(content)
                }
                if let toolCalls = result.choices[0].delta.toolCalls {
                    toolCalls.forEach {tool_call in
                        if let fn = tool_call.function, let name = fn.name, let arguments = fn.arguments?.data(using: .utf8) {
                            switch name {
                            case "around_description":
                                if let params = try? JSONDecoder().decode(AroundDescription.self, from: arguments) {
                                    NSLog("chat function \(name): \(params)")
                                    if params.is_image_required {
                                        DispatchQueue.main.async {
                                            guard let imageUrl = ChatData.shared.lastCameraImage, let viewModel = ChatData.shared.viewModel else {return}
                                            self.send(message: imageUrl)
                                            viewModel.addUserImage(base64_text: imageUrl)
                                        }
                                    }
                                }
                                break
                            case "destination_setting":
                                if let params = try? JSONDecoder().decode(DestinationSetting.self, from: arguments) {
                                    NSLog("chat function \(name): \(params)")
                                    DispatchQueue.main.async() {
                                        self.onDestinationSetting(params)
                                    }
                                }
                                break
                            case "tour_setting":
                                if let params = try? JSONDecoder().decode(TourSetting.self, from: arguments) {
                                    NSLog("chat function \(name): \(params)")
                                    DispatchQueue.main.async() {
                                        self.onTourSetting(params)
                                    }
                                }
                                break
                            default:
                                break
                            }
                        }
                    }
                }
            case .failure(let error):
                error_count += 1
                print("chat stream failure \(error)")
                break
            }
        } completion: { error in
            print("chat stream completed \(error), error_count=\(error_count), success_count=\(success_count)")
            guard let pub = self.pub else {return}
            if error_count > 0 && success_count == 0 {
                let result_id = UUID().uuidString
                self.callback?(result_id, pub)
                self.callback_called.insert(result_id)
                pub.send(CustomLocalizedString("An unexpected error has occurred", lang: I18N.shared.langCode))
            }
            pub.send(completion: .finished)
        }
    }
    
    func prepareSinkForHistory() {
        cleanupForHistory()
        guard let pub else { return }
        
        self.queryResultCancellable = pub.sink { [weak self] completion in
            let response :ChatItem.ChatResponse
            switch completion {
            case .finished:
                response = .success(self?.queryResultCache ?? "")
            case .failure(let error):
                response = .error(error)
            }
            self?.history.append(.responce(response))
            self?.cleanupForHistory()
            
            // print( " -- dump\n" + (self?.history.array.description ?? "") )
        } receiveValue: { [weak self] partial in
            self?.queryResultCache.append(partial)
        }
    }
    
    func cleanupForHistory(){
        queryResultCancellable = nil
        queryResultCache = ""
    }

    struct AroundDescription: Decodable {
        var is_image_required: Bool
    }

    struct TourSetting: Decodable {
        var tour_id: String
        var add_idx: Int
    }

    struct DestinationSetting: Decodable {
        struct DestinationManipulation: Decodable {
            struct Manipulation: Decodable {
                var manipulation_add_idx: Int
                var manipulation_type: String
            }
            var manipulation: Manipulation
            var index: Int
            var destination_id: String
        }
        var destination_manipulations: [DestinationManipulation]
        var remove_all_destinations: Bool
    }

    func onDestinationSetting(_ params: DestinationSetting) {
        guard let tourManager = ChatData.shared.tourManager else {return}
        if params.remove_all_destinations {
            tourManager.clearAllDestinations()
            NSLog("chat clear destinations")
        }
        var success = false
        params.destination_manipulations.forEach{item in
            guard let dest = tourManager.destinations.first(where: {$0.value == item.destination_id}) else {
                NSLog("chat destination_id \(item.destination_id) not found")
                return
            }
            switch item.manipulation.manipulation_type {
            case "add":
                if item.manipulation.manipulation_add_idx == 0 {
                    tourManager.stopCurrent()
                    tourManager.addToFirst(destination: dest)
                } else {
                    tourManager.addToLast(destination: dest)
                }
                NSLog("chat add destination \(dest.value)")
                success = true
                break
            default:
                NSLog("chat manipulation_type \(item.manipulation.manipulation_type) not supported")
                break
            }
        }
        if success {
            ChatData.shared.startNavigate = true
        } else {
            ChatData.shared.errorMessage = CustomLocalizedString("Could not set destination", lang: I18N.shared.langCode)
        }
    }

    func onTourSetting(_ params: TourSetting) {
        if let tourManager = ChatData.shared.tourManager, let tours: [Tour] = try? ResourceManager.shared.load().tours {
            if let tour = tours.first(where: {$0.id == params.tour_id}) {
                tourManager.set(tour: tour)
                NSLog("chat set tour: \(tour.id)")
                ChatData.shared.startNavigate = true
                return
            }
        }
        NSLog("chat tour_id \(params.tour_id) not found")
        ChatData.shared.errorMessage = CustomLocalizedString("Could not set tour", lang: I18N.shared.langCode)
    }
}

enum ChatItem {
    case query(ChatQuery)
    case responce(ChatResponse)
    
    enum ChatResponse {
        case success(String)
        case error(Error)
    }
}

extension ChatItem : CustomStringConvertible {
    var description: String {
        switch self {
        case .query(let query):
            var desc = "\n query: \n"
            for msg in query.messages {
                desc += " - \(msg.role): \(msg.content?.string ?? "???")\n"
            }
            return desc
        case .responce(let responce):
            switch responce {
            case .success(let result):
                return "\n responce(success): \n - \(result)"
            case .error(let error):
                return "\n responce(error): \n - \(error)"
            }
        }
    }
}
