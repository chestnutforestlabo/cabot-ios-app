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
    case yamlParseError(error: YamlError)
    case contentLoadError
    case nestedReferenceError
}

enum SourceType: String, Decodable {
    case local
    case remote
}

extension CodingUserInfoKey {
    static let src = CodingUserInfoKey(rawValue: "src")!
    static let i18n = CodingUserInfoKey(rawValue: "i18n")!
    static let refCount = CodingUserInfoKey(rawValue: "refCount")!
    static let error = CodingUserInfoKey(rawValue: "error")!
}

class I18N {
    var lang: String
    var tableName: String?
    var bundle: Foundation.Bundle?

    var langCode: String {
        get {
            Locale(identifier: self.lang).languageCode ?? "en"
        }
    }

    init() {
        self.lang = Locale.preferredLanguages[0]
    }

    func set(tableName: String?, bundle: Foundation.Bundle?, lang: String?) {
        self.tableName = tableName ?? "Localizable"
        self.bundle = bundle
        if let lang = lang {
            self.lang = lang
        }
    }

    func localizedString(key: String) -> String {
        guard let tableName = self.tableName else { return key }
        guard let bundle = self.bundle else { return key }

        let text = CustomLocalizedString(key, lang: self.langCode, tableName: tableName, bundle: bundle)
        // NSLog("key=\(key), tableName=\(tableName), text=\(text), bundle=\(bundle.bundleURL)")
        return text
    }
}

class ParseError {
    private var error:String = ""
    func add(error: String?) {
        guard let error = error else { return }
        if self.error.count > 0 { self.error += "\n" }
        self.error += error
    }
    func summary() -> String? {
        if self.error.count > 0 {
            return self.error
        }
        return nil
    }
}

func yamlPath(_ path: [CodingKey]) -> String{
    var ret:String = ""
    for e in path {
        if let index = e.intValue {
            ret += "[\(index)]"
        } else {
            ret += "/[\(e.stringValue)]"
        }
    }
    return ret
}

struct Source: Decodable, Hashable {
    static func == (lhs: Source, rhs: Source) -> Bool {
        return lhs.base == rhs.base && lhs.type == rhs.type && lhs.src == rhs.src
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(base)
        hasher.combine(type)
        hasher.combine(src)
    }
    let base: URL?
    let type: SourceType
    let src: String
    let i18n: I18N

    var url: URL? {
        get {
            switch(type) {
            case .local:
                let langSrc = String(format: src, i18n.langCode)
                return base?.appendingPathComponent(langSrc)
            case .remote:
                return URL(string:src)
            }
        }
    }

    var content: String? {
        get {
            if let url = url {
                return try? String(contentsOf: url)
            }
            return nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case src
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        i18n = decoder.userInfo[.i18n] as! I18N
        type = try container.decode(SourceType.self, forKey: .type)
        src = try container.decode(String.self, forKey: .src)
        base = (decoder.userInfo[.src] as? URL)?.deletingLastPathComponent()
    }

    init(base: URL?, type:SourceType, src:String, i18n:I18N) {
        self.base = base
        self.type = type
        self.src = src
        self.i18n = i18n
    }
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
    let identifier: String
    let name: String
    let i18n: I18N
    let conversation: Source?
    let destinations: Source?
    let tours: Source?
    let custom_menus: [CustomMenu]?

    static func load(at url: URL) throws -> Metadata {
        do {
            let str = try String(contentsOf: url)
            var userInfo:[CodingUserInfoKey : Any] = [:]
            userInfo[.src] = url
            userInfo[.i18n] = I18N()
            let yamlDecoder = YAMLDecoder()
            return try yamlDecoder.decode(Metadata.self, from: str, userInfo: userInfo)
        } catch let error as YamlError {
            throw MetadataError.yamlParseError(error: error)
        }
    }

    enum CodingKeys: CodingKey {
        case name
        case language
        case i18n
        case conversation
        case destinations
        case tours
        case custom_menus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // needs to have I18N instance
        let i18nTableName = try? container.decodeIfPresent(String.self, forKey: .i18n)
        var bundle: Foundation.Bundle?
        if let url = decoder.userInfo[.src] as? URL {
            bundle = Foundation.Bundle(url: url.deletingLastPathComponent())
        }
        let i18n = decoder.userInfo[.i18n] as! I18N
        self.i18n = i18n
        let language = try? container.decodeIfPresent(String.self, forKey: .language)
        i18n.set(tableName: i18nTableName, bundle: bundle, lang: language)

        self.identifier = try container.decode(String.self, forKey: .name)
        self.name = i18n.localizedString(key: self.identifier)
        self.conversation = try? container.decodeIfPresent(Source.self, forKey: .conversation)
        self.destinations = try? container.decodeIfPresent(Source.self, forKey: .destinations)
        self.tours = try? container.decodeIfPresent(Source.self, forKey: .tours)
        self.custom_menus = try? container.decodeIfPresent([CustomMenu].self, forKey: .custom_menus)
    }
}

class Resource: Hashable {
    let base: URL
    var langOverride: String?

    init(at url: URL) throws {
        base = url
        metadata = try Metadata.load(at: url.appendingPathComponent(Resource.METADATA_FILE_NAME))
    }

    static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let METADATA_FILE_NAME: String = "_metadata.yaml"

    private let metadata: Metadata

    var identifier:String {
        get {
            metadata.identifier
        }
    }

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
            self.langOverride ?? metadata.i18n.lang
        }
        set {
            self.langOverride = newValue
        }
    }

    var locale: Locale {
        return Locale.init(identifier: self.lang)
    }

    var conversationSource: Source? {
        get {
            if let c = metadata.conversation {
                return c
            }
            return nil
        }
    }

    var destinationsSource: Source? {
        get {
            if let d = metadata.destinations {
                return d
            }
            return nil
        }
    }

    var toursSource: Source? {
        get {
            if let t = metadata.tours {
                return t
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

    var languages: [String] {
        get {
            var languages:[String] = []
            if let directoryContents = try? FileManager.default.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                for directory in directoryContents {
                    if directory.pathExtension == "lproj" {
                        languages.append(directory.deletingPathExtension().lastPathComponent)
                    }
                }
            }
            if languages.contains(where: {lang in lang == metadata.i18n.lang }) == false {
                languages.append(metadata.i18n.lang)
            }
            return languages
        }
    }
}


/// Destination for the robot waiting position
///
/// ```
/// - title: <String> Display text for the destination
///    - the text can be localizable
/// - value: <String> Navigation node ID
/// - pron: <String> Reading text for the destination if required other wise title is used for reading
///    - the text can be localizable
/// ```
struct WaitingDestination: Decodable {
    let title:String
    let value:String?
    let pron:String?

    enum CodingKeys: String, CodingKey {
        case title
        case value
        case pron
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let i18n = decoder.userInfo[.i18n] as! I18N

        let title = try container.decode(String.self, forKey: .title)
        self.title = i18n.localizedString(key: title)
        value = try? container.decode(String.self, forKey: .value)
        if let pron = try? container.decode(String.self, forKey: .pron) {
            let i18n_pron = i18n.localizedString(key: pron)
            if i18n_pron.count == 0 {  // assume there is no localized pron
                self.pron = title
            } else {
                self.pron = i18n_pron
            }
        } else {
            self.pron = nil
        }
    }
}

struct Reference: CustomStringConvertible {
    let file: String
    let value: String

    static func from(ref: String) -> Reference? {
        if let index = ref.firstIndex(of: "/") {
            let file = String(ref[..<index])
            let value = String(ref[ref.index(index, offsetBy: 1)...])
            return Reference(file: file, value:value)
        }
        return nil
    }

    var description: String {
        return "\(file)/\(value)"
    }
}

/// Destination for the navigation
///
/// ```
/// - ref: <String> if ref is specified with the format (<local file>/<value>), it will copy properties from the destination that has <value> in the <local file>
///   - if other properties are specified too, it will override
/// - title: <String> Display text for the destination
///   - the text can be localizable
/// - value: <String> Navigation node ID
/// - pron: <String> Reading text for the destination if required other wise title is used for reading
///    - the text can be localizable
/// - file: <Source> file including a list of destinations
/// - message: <Source> file including a message text
/// - content: <Source> file including a web content to show in the browser
/// - waitingDestination: <WaitingDestination>
/// ```
class Destination: Decodable, Hashable {
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
    let file:Source?
    let message:Source?
    let content:Source?
    let waitingDestination:WaitingDestination?
    let subtour:Tour?
    let error:String?

    enum CodingKeys: String, CodingKey {
        case title
        case ref
        case value
        case pron
        case file
        case message
        case content
        case waitingDestination
        case subtour
    }

    static func load(at src: Source, refCount: Int = 0, reference: Reference? = nil) throws -> [Destination] {
        do {
            guard let url = src.url else { throw MetadataError.contentLoadError }
            let str = try String(contentsOf: url)
            var userInfo:[CodingUserInfoKey : Any] = [:]
            userInfo[.src] = url
            userInfo[.i18n] = src.i18n
            userInfo[.refCount] = refCount

            let node = try Yams.load(yaml: str)
            guard let yaml = node as? Array<Any> else { throw MetadataError.contentLoadError }
            let yamlDecoder = YAMLDecoder()
            var temp: [Destination] = []
            for node in yaml {
                guard let dict = node as? Dictionary<String, Any> else { continue }
                let value = dict["value"] as? String
                
                if reference == nil || value == reference?.value {
                    let str = try Yams.dump(object: node)
                    let dest = try yamlDecoder.decode(Destination.self, from: str, userInfo: userInfo)
                    temp.append(dest)
                }
            }
            return temp
        } catch let error as YamlError {
            throw MetadataError.yamlParseError(error: error)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let src = decoder.userInfo[.src] as! URL
        let base = src.deletingLastPathComponent()
        let i18n = decoder.userInfo[.i18n] as! I18N
        let refCount = decoder.userInfo[.refCount] as! Int
        let error = ParseError()
        var refDest: Destination?
        

        // if 'ref' is specified, try to find a destination
    outer: if let refstr = try? container.decode(String.self, forKey: .ref) {
            guard refCount < 10 else {
                error.add(error: CustomLocalizedString("Too deep nested reference \(refCount) [ref]=\(refstr)", lang: i18n.lang))
                break outer
            }
            if let ref = Reference.from(ref: refstr) {
                let refSrc = Source(base: base, type: .local, src: ref.file, i18n: i18n)
                if let tempDest = try? Destination.load(at: refSrc, refCount: refCount+1, reference: ref) {
                    if tempDest.count == 1 {
                        refDest = tempDest[0]
                    } else if tempDest.count > 1 {
                        error.add(error: CustomLocalizedString("Found multiple \(ref.file)/\(ref.value)", lang: i18n.lang))

                    } else {
                        error.add(error: CustomLocalizedString("Cannot find \(ref.file)/\(ref.value)", lang: i18n.lang))
                    }
                } else {
                    error.add(error: CustomLocalizedString("Parse Error \(ref.file)/\(ref.value)", lang: i18n.lang))
                }
            } else {
                error.add(error: CustomLocalizedString("Reference error (syntax='file/value')", lang: i18n.lang))
            }
        }

        if let title = try? container.decode(String.self, forKey: .title) {
            self.title = i18n.localizedString(key: title)
        } else if let title = refDest?.title {
            self.title = title
        } else {
            self.title = CustomLocalizedString("NO TITLE", lang: i18n.lang)
            error.add(error: CustomLocalizedString("No title specified", lang: i18n.lang))
        }
        value = try? container.decode(String.self, forKey: .value)
        if let pron = try? container.decode(String.self, forKey: .pron) {
            self.pron = i18n.localizedString(key: pron)
        } else {
            self.pron = refDest?.pron
        }
        // ToDo: should not refer that has file prop (need to separate)
        self.file = try? container.decode(Source.self, forKey: .file)
        if let message = try? container.decode(Source.self, forKey: .message) {
            self.message = message
        } else {
            self.message = refDest?.message
        }
        if let content = try? container.decode(Source.self, forKey: .content) {
            self.content = content
        } else {
            self.content = refDest?.content
        }
        
    outer: if let subtour = try? container.decode(String.self, forKey: .subtour) {
            guard refCount < 5 else {
                error.add(error: CustomLocalizedString("Nested reference [ref]=\(subtour)", lang: i18n.lang))
                self.subtour = nil
                break outer
            }
            if let ref = Reference.from(ref: subtour) {
                let src = Source(base: base, type: .local, src: ref.file, i18n: i18n)
                if let tempTour = try? Tour.load(at: src, refCount: refCount+1, reference: ref) {
                    if tempTour.count == 1 {
                        self.subtour = tempTour[0]
                        error.add(error: tempTour[0].error)
                    } else if tempTour.count > 1 {
                        self.subtour = nil
                        error.add(error: CustomLocalizedString("Found multiple \(ref.file)/\(ref.value)", lang: i18n.lang))
                    } else {
                        self.subtour = nil
                        error.add(error: CustomLocalizedString("Cannot find \(ref.file)/\(ref.value)", lang: i18n.lang))
                    }
                } else {
                    self.subtour = nil
                    error.add(error: CustomLocalizedString("Parse Error \(ref.file)/\(ref.value)", lang: i18n.lang))
                }
            } else {
                self.subtour = nil
                error.add(error:CustomLocalizedString("Reference error (syntax='file/value')", lang: i18n.lang))
            }
        } else {
            self.subtour = refDest?.subtour
        }
        if let waitingDestination = try? container.decode(WaitingDestination.self, forKey: .waitingDestination) {
            self.waitingDestination = waitingDestination
        } else {
            self.waitingDestination = refDest?.waitingDestination
        }
        
        if error.summary() != nil {
            error.add(error: CustomLocalizedString("Error at \(src.lastPathComponent)\(yamlPath(decoder.codingPath))", lang: i18n.lang))
        }
        
        if error.summary() == nil, let refError = refDest?.error {
            error.add(error: refError)
            error.add(error: CustomLocalizedString("Error at \(src.lastPathComponent)\(yamlPath(decoder.codingPath))", lang: i18n.lang))
        }
        self.error = error.summary()
    }
    
    init(title: String, value: String?, pron: String?, file: Source?, message: Source?, content: Source?, waitingDestination: WaitingDestination?, subtour: Tour?) {
        self.title = title
        self.value = value
        self.pron = pron
        self.file = file
        self.message = message
        self.content = content
        self.waitingDestination = waitingDestination
        self.subtour = subtour
        self.error = nil
    }
}

protocol TourProtocol {
    var title: String { get }
    var pron: String? { get }
    var id: String { get }
    var destinations: [Destination] { get }
    var currentDestination: Destination? { get }
}

class Tour: Decodable, Hashable, TourProtocol {
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
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case pron
        case id
        case destinations
    }
    
    static func load(at src: Source, refCount: Int = 0, reference: Reference? = nil) throws -> [Tour] {
        do {
            guard let url = src.url else { throw MetadataError.contentLoadError }
            let str = try String(contentsOf: url)
            var userInfo:[CodingUserInfoKey : Any] = [:]
            userInfo[.src] = url
            userInfo[.i18n] = src.i18n
            userInfo[.refCount] = refCount
            
            let node = try Yams.load(yaml: str)
            guard let yaml = node as? Array<Any> else { throw MetadataError.contentLoadError }
            let yamlDecoder = YAMLDecoder()
            var temp: [Tour] = []
            for node in yaml {
                guard let dict = node as? Dictionary<String, Any> else { continue }
                let value = dict["id"] as? String
                
                if reference == nil || value == reference?.value {
                    let str = try Yams.dump(object: node)
                    let dest = try yamlDecoder.decode(Tour.self, from: str, userInfo: userInfo)
                    temp.append(dest)
                }
            }
            return temp
        } catch let error as YamlError {
            throw MetadataError.yamlParseError(error: error)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let i18n = decoder.userInfo[.i18n] as! I18N
        let error = ParseError()
        if let title = try? container.decode(String.self, forKey: .title) {
            self.title = i18n.localizedString(key: title)
        } else {
            self.title = CustomLocalizedString("ERROR", lang: i18n.lang)
            error.add(error: CustomLocalizedString("No title specified", lang: i18n.lang))
        }
        if let pron = try? container.decode(String.self, forKey: .pron) {
            self.pron = i18n.localizedString(key: pron)
        } else {
            self.pron = nil
        }
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            self.id = "ERROR"
            error.add(error: CustomLocalizedString("No ID specified", lang: i18n.lang))
        }

        if let destinations = try? container.decode([Destination].self, forKey: .destinations) {
            self.destinations = destinations
            for d in destinations {
                error.add(error: d.error)
            }
        } else {
            self.destinations = []
            error.add(error: CustomLocalizedString("No destinations specified", lang: i18n.lang))
        }
        self.error = error.summary()
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

    public func resource(by identifier: String) -> Resource? {
        NSLog("identifier=\(identifier)")
        for resource in resources {
            NSLog("resource.identifier = \(resource.identifier)")
            if resource.identifier == identifier {
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
