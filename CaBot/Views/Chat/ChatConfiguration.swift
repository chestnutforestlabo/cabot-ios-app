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

import Foundation


class ChatConfiguration : ObservableObject {
    @Published public var host : String {
        didSet {
            Settings.host.set( host )
        }
    }
    @Published public var apiKey : String {
        didSet {
            Settings.apiKey.set( apiKey )
        }
    }
    @Published public var model : String {
        didSet {
            Settings.model.set( model )
        }
    }
    @Published public var historySize : Int {
        didSet {
        }
    }

    init(historySize : Int = 20) {
        self.host = Settings.host.get(default:"http://localhost:8080/v1")
        self.model = Settings.model.get(default:"ollama/llama3.2")
        self.apiKey = Settings.apiKey.get(default:"")
        self.historySize = historySize
    }
}



extension ChatConfiguration {
    enum Settings : String {
        case host
        case model
        case apiKey
        
        var key :String { "config_\(self.rawValue)" }
        func get( default value:String ) -> String { UserDefaults.standard.string(forKey:self.key) ?? value }
        func get() -> Int { UserDefaults.standard.integer(forKey:self.key) }
        func set( _ value:String ) { UserDefaults.standard.set(value, forKey:self.key) }
        func set( _ value:Int ) { UserDefaults.standard.set(value, forKey:self.key) }
    }
    
    var isValid : Bool {
        !host.isEmpty && !apiKey.isEmpty
    }
}
