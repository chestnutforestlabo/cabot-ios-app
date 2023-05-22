/*******************************************************************************
 * Copyright (c) 2023  Carnegie Mellon University
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
import NaturalLanguage
import WebKit

func CustomLocalizedString(_ key:String, lang:String, _ args:String...) -> String {
    let tableName:String = "Localizable"
    let bundle:Bundle = Bundle.main
    
    if let path = bundle.path(forResource: lang, ofType: "lproj") {
        let bundle = Bundle(path: path)
        if let string = bundle?.localizedString(forKey: key, value: nil, table: tableName) {
            if args.count == 1 {
                return String(format: string, args[0])
            } else {
                return String(format: string)
            }
        }
    }

    let langCode = String(lang.prefix(2))
    if let path = bundle.path(forResource: langCode, ofType: "lproj") {
        let bundle = Bundle(path: path)
        if let string = bundle?.localizedString(forKey: key, value: nil, table: tableName) {
            if args.count == 1 {
                return String(format: string, args[0])
            } else {
                return String(format: string)
            }
        }
    }
    return key
}

class LanguageDetector {
    let string: String?
    var target: String? = nil
    var wait: Bool = true

    init(string: String?) {
        self.string = string
    }

    func detect() -> String? {
        let recognizer = NLLanguageRecognizer()
        
        if let plainText = string {
            self.target = plainText
            if plainText.contains("html") {
                self.wait = true
                NSAttributedString.loadFromHTML(string: plainText) { html, attr, error in
                    self.target = html?.string
                    self.wait = false
                }
                DispatchQueue.global().sync {
                    while self.wait {
                        RunLoop.current.run(mode: .default, before: .distantFuture)
                    }
                }
            }
            if let target = self.target {
                recognizer.processString(target)
                guard let languageCode = recognizer.dominantLanguage?.rawValue else { return nil }
                return languageCode
            }
        }
        return nil
    }
}
