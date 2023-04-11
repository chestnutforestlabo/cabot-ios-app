import ArgumentParser
import Foundation

@main
struct ResourceChecker: ParsableCommand {
        
    @Flag(name: .short, help: "analyze all even if error")
    var analyseAllEvenIfError: Bool = false

    @Flag(name: .short, help: "analyze destinations only")
    var destinationsOnly: Bool = false
    
    @Flag(name: .short, help: "analyze tours only")
    var toursOnly: Bool = false

    @Option(name: .short, help: "specify lang code to be checked")
    var langCode: String? = nil

    //@Option(name: .shortAndLong, help: "The root directory to check resource")
    //var dir: String? = nil

    @Argument(help: "The root directory to check resource")
    var dir: String

    mutating func run() throws {
        emitInfo("Analyse all even if error: \(analyseAllEvenIfError)")
        emitInfo("Analyse root directory   : \(dir)")
        
        guard let enumerator = FileManager.default.enumerator(atPath: dir) else {
            emitInfo("cannot open \(dir)")
            return
        }
        for f in enumerator {
            guard let path = f as? String else { continue }
            let name = FileManager.default.displayName(atPath: path)
            guard name == "_metadata.yaml" else { continue }

            let url = URL(filePath: dir+"/"+path)
            emitInfo("Parsing Metadata... \(url)")
            if !analyse(metadata: url) {
                break
            }
        }
    }
    
    func emitError(_ message: String, indent: String = "") {
        emitCommon(message, icon: "🚫", indent: indent)
        if !analyseAllEvenIfError {
            abort()
        }
    }
    func emitWarn(_ message: String, indent: String = "") {
        emitCommon(message, icon: "⚠️", indent: indent)
    }
    func emitInfo(_ message: String, indent: String = "", warn: String? = nil, error: String? = nil) {
        if let error = error {
            emitCommon(message+" 🚫"+error, indent: indent)
        } else if let warn = warn {
            emitCommon(message+" ⚠️"+warn, indent: indent)
        } else {
            emitCommon(message, indent: indent)
        }
    }
    
    func emitCommon(_ message: String, icon: String = "", indent: String = "") {
        let components = message.components(separatedBy: "\n")
        var first = true
        for c in components {
            if first {
                print("\(indent)\(icon)\(c)")
            }
            else {
                print("\(indent) | \(c)")
            }
            first = false
        }
    }
    
    
    func analyse(metadata url: URL) -> Bool {
        let base = url.deletingLastPathComponent()
        do {
            let metadata = try Metadata.load(at: url)
            
            var languages = metadata.name.languages
            emitInfo("Supported Language: \(languages)")
            
            for lang in languages {
                I18N.shared.set(lang: lang)
                emitInfo("name(\(lang)): \(metadata.name.text) (\(metadata.name.pron))")
            }
            
            if let langCode = langCode {
                languages = [langCode]
                emitInfo("Analyse only \(langCode)")
            }
            
            if destinationsOnly || toursOnly == false {
                if let source = metadata.destinations {
                    analyse(destinations: source, languages: languages, indent: "")
                }
            }
            
            if toursOnly || destinationsOnly == false {
                if let source = metadata.tours {
                    analyse(tours: source, languages: languages, indent: "")
                }
            }
            
        } catch MetadataError.yamlParseError(let error) {
            emitError("Metadata has an error: \(error)")
        } catch {
            emitError("\(error)")
        }
        return true
    }
    
    func analyse(destinations: Source, languages: [String], indent: String) -> Void {
        for lang in languages {
            emitInfo("Destination file \(destinations.src) is loading - lang=\(lang)", indent: indent)
            destinations.i18n.set(lang: lang)
            
            do {
                let destinations = try Destination.load(at: destinations)
                
                for index in 0..<destinations.count {
                    let destination = destinations[index]
                    emitInfo("- [\(index)]", indent: indent)
                    analyse(destination: destination, languages: languages, indent: indent+"  ")
                }
            } catch MetadataError.yamlParseError(let error) {
                emitError("Destination has an error: \(error)", indent: indent)
            } catch {
                emitError("\(error)", indent: indent)
            }
        }
    }
    
    func analyse(destination: Destination, languages: [String], indent: String) -> Void {
        if let ref = destination.ref {
            if let refDest = destination.refDest {
                emitInfo("# reference (\(ref.description))", indent: indent)
                let title = destination.title.text
                if title != refDest.title.text {
                    emitInfo("title: \(title) # overwritten from \"\(refDest.title.text)\"", indent: indent, warn: destination.title.warn)
                } else {
                    emitInfo("title: \(title)", indent: indent, warn: destination.title.warn)
                }
                let pron = destination.title.pron
                if pron != refDest.title.pron {
                    emitInfo("pron : \(pron) # overwritten from \"\(refDest.title.pron)\"", indent: indent, warn: destination.title.warn)
                } else {
                    emitInfo("pron : \(pron)", indent: indent, warn: destination.title.warn)
                }
                
                if let value = destination.value {
                    if value != refDest.value {
                        emitInfo("value: \(value) # overwritten from \"\(refDest.value!)\"", indent: indent)
                    } else {
                        emitInfo("value: \(value)", indent: indent)
                    }
                }
                                
                if let file = destination.file {
                    emitError("file: \(file) reference should not have file prop", indent: indent)
                }
                if let message = destination.message {
                    if message != refDest.message {
                        emitInfo("message: \(message) # overwritten", indent: indent, warn: message.warn, error: message.error)
                    } else {
                        emitInfo("message: \(message)", indent: indent, warn: message.warn, error: message.error)
                    }
                }
                if let content = destination.content {
                    if content != refDest.content {
                        emitInfo("content: \(content) # overwritten", indent: indent, warn: content.warn, error: content.error)
                    } else {
                        emitInfo("content: \(content)", indent: indent, warn: content.warn, error: content.error)
                    }
                }
                if let subtour = destination.subtour {
                    if subtour != refDest.subtour {
                        emitInfo("subtour: # overwritten", indent: indent)
                        analyse(tour: subtour, languages: languages, indent: indent+"  ")
                    } else {
                        emitInfo("subtour:", indent: indent)
                        analyse(tour: subtour, languages: languages, indent: indent+"  ")
                    }
                }
                if let waitingDestination = destination.waitingDestination {
                    if waitingDestination != refDest.waitingDestination {
                        emitInfo("waiting title: \(waitingDestination.title.text)  # overwritten", indent: indent)
                        emitInfo("        pron : \(waitingDestination.title.pron)", indent: indent)
                        emitInfo("        value: \(waitingDestination.value)", indent: indent)
                    } else {
                        emitInfo("waiting title: \(waitingDestination.title.text)", indent: indent)
                        emitInfo("        pron : \(waitingDestination.title.pron)", indent: indent)
                        emitInfo("        value: \(waitingDestination.value)", indent: indent)
                    }
                }
                if let error = destination.error {
                    emitError("\(error)", indent: indent)
                }
                
            } else {
                emitError("❗️may have issue")
            }
        } else {
            let title = destination.title.text
            emitInfo("title: \(title)", indent: indent, warn: destination.title.warn)
            let pron = destination.title.pron
            emitInfo("pron : \(pron)", indent: indent, warn: destination.title.warn)
            
            if let value = destination.value {
                emitInfo("value: \(value)", indent: indent)
            }
            if let file = destination.file {
                emitInfo("file: \(file.src)", indent: indent)
                analyse(destinations: file, languages: languages, indent: indent+"    ")
            }
            if let message = destination.message {
                emitInfo("message: \(message)", indent: indent, warn: message.warn, error: message.error)
            }
            if let content = destination.content {
                emitInfo("content: \(content)", indent: indent, warn: content.warn, error: content.error)
            }
            if let subtour = destination.subtour {
                emitInfo("subtour:", indent: indent)
                for dest in subtour.destinations {
                    analyse(destination: dest, languages: languages, indent: indent+"  ")
                }
            }
            if let waitingDestination = destination.waitingDestination {
                emitInfo("waiting title: \(waitingDestination.title.text)", indent: indent)
                emitInfo("        pron : \(waitingDestination.title.pron)", indent: indent)
                emitInfo("        value: \(waitingDestination.value)", indent: indent)
            }
            if let error = destination.error {
                emitError("\(error)", indent: indent)
            }
        }
    }
        
    func analyse(tours: Source, languages: [String], indent: String) -> Void {
        for lang in languages {
            emitInfo("Tour file \(tours.src) is loading - lang=\(lang)", indent: indent)
            tours.i18n.set(lang: lang)
            
            do {
                let tours = try Tour.load(at: tours)
                
                for index in 0..<tours.count {
                    let tour = tours[index]
                    emitInfo("- [\(index)]", indent: indent)
                    analyse(tour: tour, languages: languages, indent: indent+"  ")
                }
            } catch MetadataError.yamlParseError(let error) {
                emitError("Tour has an error: \(error)", indent: indent)
            } catch {
                emitError("\(error)", indent: indent)
            }
        }
    }
    
    func analyse(tour: Tour, languages: [String], indent: String) -> Void {
        
        let title = tour.title.text
        emitInfo("title: \(title)", indent: indent, warn: tour.title.warn)
        let pron = tour.title.pron
        emitInfo("pron: \(pron)", indent: indent, warn: tour.title.warn)

        emitInfo("destinations: ", indent: indent)
        for index in 0..<tour.destinations.count {
            let dest = tour.destinations[index]
            emitInfo("- [\(index)]", indent: indent)
            analyse(destination: dest, languages: languages, indent: indent+"  ")
        }
        
        if let error = tour.error {
            emitError("\(error)", indent: indent)
        }
    }
}
