import ArgumentParser
import Foundation

@main
struct ResourceChecker: ParsableCommand {
        
    @Flag(name: .short, help: "analyze all even if error")
    var analyzeAllEvenIfError: Bool = false

    //@Option(name: .shortAndLong, help: "The root directory to check resource")
    //var dir: String? = nil

    @Argument(help: "The root directory to check resource")
    var dir: String

    mutating func run() throws {
        print(analyzeAllEvenIfError)
        
        guard let enumerator = FileManager.default.enumerator(atPath: dir) else {
            print("cannot open \(dir)")
            return
        }
        for f in enumerator {
            guard let path = f as? String else { continue }
            let name = FileManager.default.displayName(atPath: path)
            guard name == "_metadata.yaml" else { continue }

            print("Found Resource \(path)")
            let url = URL(filePath: dir+"/"+path)
            print("Parsing Metadata...")
            if !analyse(url: url) {
                break
            }
        }
    }
    
    func analyse(url: URL) -> Bool {
        print("--------------------Analysing \(url)")
        let base = url.deletingLastPathComponent()
        guard let bundle = Bundle(url: base) else { print("cannot make bundle at \(base.path())"); return analyzeAllEvenIfError }
        guard let enumerator = FileManager.default.enumerator(atPath: base.path()) else { print("cannot enumerate files at \(base.path())"); return analyzeAllEvenIfError}
        do {
            let metadata = try Metadata.load(at: url)
            
            var languages:[String] = []
            for f in enumerator {
                guard let path = f as? String else { continue }
                if path.hasSuffix(".lproj") {
                    let name = base.appending(path: path).lastPathComponent
                    let lang = String(name[..<name.lastIndex(of: ".")!])
                    languages.append(lang)
                }
            }
            print("Supported Language: \(languages)")
            printI18N(label: "name", key: metadata.name, languages: languages, tableName: metadata.i18n.tableName, bundle: bundle)
            
            do {
                if let source = metadata.destinations {
                    for lang in languages {
                        print("Destination file \(source.src) is loading")
                        source.i18n.set(tableName: source.i18n.tableName, bundle: bundle, lang: lang)
                        print(source.i18n.lang)
                        let destinations = try Destination.load(at: source)
                        for index in 0..<destinations.count {
                            let destination = destinations[index]
                            print("[\(index)]")
                            let title = destination.title
                            print("  title: \(title)")
                            if let pron = destination.pron {
                                print("  pron: \(pron)")
                            }
                            if let value = destination.value {
                                print("  value: \(value)")
                            }
                            if let file = destination.file {
                                print("  file: \(file.src)")
                            }
                            if let message = destination.message {
                                print("  message: \(message.src)")
                            }
                            if let content = destination.content {
                                print("  content: \(content.src)")
                            }
                            if let subtour = destination.subtour {
                                print("  subtour: \(subtour)")
                            }
                            if let error = destination.error {
                                print("❗️", error)
                                if !analyzeAllEvenIfError {
                                    return false
                                }
                            }
                        }
                    }
                    print("Destination is loaded without error")
                }
            } catch MetadataError.yamlParseError(let error) {
                print("Metadata has an error: \(error)")
            } catch {
                print(error)
            }
            
        } catch MetadataError.yamlParseError(let error) {
            print("Metadata has an error: \(error)")
        } catch {
            print(error)
        }
        print("--------------------Analyzing end")
        return true
    }
    
    func printI18N(label: String, key: String, languages: [String], tableName: String?, bundle: Bundle) {
        print("  \(label): \(key)")
        for lang in languages {
            let text = CustomLocalizedString(key, lang: lang, tableName: tableName ?? "Localizable", bundle: bundle)
            print("  \(label)(\(lang)): \(text)")
        }
    }
}
