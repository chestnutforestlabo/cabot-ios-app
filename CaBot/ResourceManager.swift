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

enum MetadataError: Error {
    case noName
    case yamlParseError
    case contentLoadError
}

enum SourceType: String, Decodable {
    case local
    case remote
}

struct Source: Decodable {
    let type: SourceType
    let src: String
}

struct CustomMenu: Decodable, Hashable {
    static func == (lhs: CustomMenu, rhs: CustomMenu) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let title: String
    let id: String
    let script: Source
    let function: String
}

struct Metadata: Decodable{
    let name: String
    let language: String
    let conversation: Source?
    let destinations: Source?
    let tours: Source?
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

class URLResolvable {
    let base: URL

    init(at url:URL) throws {
        base = url
    }

    func resolveURL(from src:String) -> URL {
        return base.appendingPathComponent(src)
    }

    func resolveURL(from src:Source) -> URL {
        switch(src.type) {
        case .local:
            return base.appendingPathComponent(src.src)
        case .remote:
            return URL(fileURLWithPath: src.src)
        }
    }
}

class Resource: URLResolvable, Hashable {
    static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let METADATA_FILE_NAME: String = "_metadata.yaml"

    private let metadata: Metadata

    var name:String {
        get {
            metadata.name
        }
    }

    var id:String {
        get {
            base.path
        }
    }

    var lang: String {
        get {
            metadata.language
        }
    }

    var locale: Locale {

        return Locale.init(identifier: self.lang)
    }

    var conversationURL: URL? {
        get {
            if let c = metadata.conversation {
                return self.resolveURL(from: c)
            }
            return nil
        }
    }

    var destinationsURL: URL? {
        get {
            if let d = metadata.destinations {
                return self.resolveURL(from: d)
            }
            return nil
        }
    }

    var toursURL: URL? {
        get {
            if let d = metadata.tours {
                return self.resolveURL(from: d)
            }
            return nil
        }
    }

    var customeMenus: [CustomMenu] {
        get {
            if let cm = metadata.custom_menus {
                return cm
            }
            return []
        }
    }

    override init(at url: URL) throws {
        metadata = try Metadata.load(at: url.appendingPathComponent(Resource.METADATA_FILE_NAME))
        try super.init(at: url)
    }
}

struct Destination: Decodable, Hashable {
    static func == (lhs: Destination, rhs: Destination) -> Bool {
        if let lhsfile = lhs.file,
           let rhsfile = rhs.file {
            return lhsfile.type == rhsfile.type && lhsfile.src == rhsfile.src
        }
        if let lhsvalue = lhs.value,
           let rhsvalue = rhs.value {
            return lhsvalue == rhsvalue
        }
        return false
    }

    func hash(into hasher: inout Hasher) {
        if let file = file {
            hasher.combine(file.type)
            hasher.combine(file.src)
        }
        if let value = value {
            hasher.combine(value)
        }
    }

    let title:String
    let value:String?
    let pron:String?
    let file: Source?
}

class Destinations: URLResolvable {
    let list: [Destination]

    override init(at url: URL) throws {
        do {
            let str = try String(contentsOf: url)
            guard let yaml = try Yams.load(yaml: str) else { throw MetadataError.yamlParseError }
            let json = try JSONSerialization.data(withJSONObject: yaml)
            list = try JSONDecoder().decode([Destination].self, from: json)
        } catch is YamlError {
            throw MetadataError.yamlParseError
        }
        try super.init(at: url.deletingLastPathComponent())
    }
}

protocol TourProtocol {
    var title: String { get }
    var pron: String? { get }
    var id: String { get }
    var destinations: [Destination] { get }
    var currentDestination: Destination? { get }
}

struct Tour: Decodable, Hashable, TourProtocol {
    static func == (lhs: Tour, rhs: Tour) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let title: String
    let pron: String?
    let id: String
    let destinations: [Destination]
    var currentDestination: Destination? = nil
}

class Tours: URLResolvable {
    let list: [Tour]

    override init(at url: URL) throws {
        do {
            let str = try String(contentsOf: url)
            guard let yaml = try Yams.load(yaml: str) else { throw MetadataError.yamlParseError }
            let json = try JSONSerialization.data(withJSONObject: yaml)
            list = try JSONDecoder().decode([Tour].self, from: json)
        } catch is YamlError {
            throw MetadataError.yamlParseError
        }
        try super.init(at: url.deletingLastPathComponent())
    }
}

class ResourceManager {
    public static let shared: ResourceManager = ResourceManager(preview: false)

    private var _resources: [Resource] = []
    private var _resourceMap: [String: Resource] = [:]
    var resources: [Resource] {
        get {
            return _resources
        }
    }

    let preview: Bool

    init(preview: Bool) {
        self.preview = preview
        updateResources()
    }

    public func resolveContentURL(url: URL) -> URL? {
        let abs = url.absoluteString
        if abs.starts(with: "content://") == false {
            return nil
        }

        let path = abs[abs.index(abs.startIndex, offsetBy: 10)...]
        return getResourceRoot().appendingPathComponent(String(path))
    }

    public func updateResources() {
        _resources = listAllResources()
        _resourceMap = [:]

        for resource in resources {
            _resourceMap[resource.id] = resource
        }
    }

    public func resource(by name: String) -> Resource? {
        for resource in resources {
            if resource.name == name {
                return resource
            }
        }
        return nil
    }

    func getResourceRoot() -> URL {
        if preview {
            let path = Bundle.main.resourceURL
            return path!.appendingPathComponent("PreviewResource")

        } else {
            let path = Bundle.main.resourceURL
            return path!.appendingPathComponent("Resource")
        }
    }

    private func listAllResources() -> [Resource] {
        var list: [Resource] = []

        let resourceRoot = getResourceRoot()

        let fm = FileManager.default
        do {
            for dir in try fm.contentsOfDirectory(at: resourceRoot,
                                                  includingPropertiesForKeys: [.isDirectoryKey],
                                                  options: []) {
                if fm.fileExists(atPath: dir.appendingPathComponent(Resource.METADATA_FILE_NAME).path) {
                    do {
                        let model = try Resource(at: dir)
                        list.append(model)
                    } catch (let error) {
                        NSLog(error.localizedDescription)
                    }
                }
            }
        } catch {
            NSLog("Could not get file list at \(resourceRoot)")
        }

        return list.sorted { r1, r2 in
            r1.name < r2.name
        }
    }


}
