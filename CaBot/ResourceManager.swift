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

import Foundation
import Yams

class Model {
    static let METADATA_FILE_NAME: String = "_metadata.yaml"
    enum MetadataError: Error {
        case noName
        case yamlParseError
        case contentLoadError
    }

    struct Metadata: Decodable{
        struct Source: Decodable {
            let type: String
            let src: String
        }
        struct CustomMenu: Decodable {
            let title: String
            let id: String
            let script: String
            let function: String
        }

        let name: String
        let language: String
        let conversation: Source?
        let destinations: Source?
        let custom_menus: [CustomMenu]?

        static func load(at url: URL) throws -> Metadata {
            do {
                let str = try String(contentsOf: url)
                guard let yaml = try Yams.load(yaml: str) as? [String: Any?] else { throw MetadataError.yamlParseError }
                let json = try JSONSerialization.data(withJSONObject: yaml)
                return try JSONDecoder().decode(Metadata.self, from: json)
            } catch is YamlError {
                throw MetadataError.yamlParseError
            }
        }
    }
    private let path: URL
    private let metadata: Metadata

    var name:String {
        get {
            metadata.name
        }
    }

    var id:String {
        get {
            path.path
        }
    }

    var coversationURL: URL? {
        get {
            if let c = metadata.conversation {
                return self.resolveURL(from: c.src)
            }
            return nil
        }
    }

    var destinationsURL: URL? {
        get {
            if let d = metadata.destinations {
                return self.resolveURL(from: d.src)
            }
            return nil
        }
    }

    var customeMenus: [Metadata.CustomMenu] {
        get {
            if let cm = metadata.custom_menus {
                return cm
            }
            return []
        }
    }

    func resolveURL(from file:String) -> URL {
        return path.appendingPathComponent(file)
    }

    init(at url: URL) throws {
        path = url

        metadata = try Metadata.load(at: path.appendingPathComponent(Model.METADATA_FILE_NAME))
    }
}

class ResourceManager {
    public static let shared: ResourceManager = ResourceManager()

    private var _models: [Model] = []
    private var _modelMap: [String: Model] = [:]
    var models: [Model] {
        get {
            return _models
        }
    }
    private var _currentModel: Model?
    public var currentModel: Model? {
        get {
            _currentModel
        }
    }
    var hasDefaultModel: Bool {
        return _currentModel != nil
    }

    init() {
        updateModels()
    }

    public func updateModels() {
        _models = ResourceManager.listAllModels()
        _modelMap = [:]
        for model in models {
            _modelMap[model.id] = model
        }
    }

    public func selectModel(by id:String) {
        if let model = _modelMap[id] {
            _currentModel = model
        }
    }

    static private func listAllModels() -> [Model] {
        var list: [Model] = []

        let fm = FileManager.default
        if let path = Bundle.main.resourceURL {
            let path2 = path.appendingPathComponent("Resource")
            do {
                for dir in try fm.contentsOfDirectory(at: path2,
                                                      includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: []) {
                    if fm.fileExists(atPath: dir.appendingPathComponent(Model.METADATA_FILE_NAME).path) {
                        do {
                            let model = try Model(at: dir)
                            list.append(model)
                        } catch (let error) {
                            NSLog(error.localizedDescription)
                        }
                    }
                }
            } catch {
                NSLog("Could not get file list at \(path)")
            }
        }
        return list
    }


}
