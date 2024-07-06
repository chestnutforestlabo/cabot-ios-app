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

import UIKit
import Foundation
import CommonCrypto
import ZIPFoundation
import SwiftUI

//Get document directory
func getDocumentsDirectory() -> URL{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return paths
}

//Since there is no Hash file in the app, save it for the first time
func saveHashTextFile(fileName:String,content:String)
{
    let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
    
    //Check file existence
    if FileManager.default.fileExists(atPath: fileURL.path)
    {
        //do nothing
    }else{//If the file does not exist, create a new one
        do{
            try content.write(to:fileURL, atomically: true, encoding: .utf8)
            print("Saving of Hash file is completed:\(fileURL.path)")
        }catch{
            print("Saving Hash file failed:\(error.localizedDescription)")
        }
    }
}

//Delete hash files on retry
func deleteHashFile()
{
    let hashFileName = "hashFile.txt"//Hash file name saved within the app
    let hashFileURL = getDocumentsDirectory().appendingPathComponent(hashFileName)
    //Delete if file already exists
    if FileManager.default.fileExists(atPath: hashFileURL.path) {
        do{
            print("Hash file deletion completed:\(hashFileURL.path)")
            try FileManager.default.removeItem(at: hashFileURL)
        }catch
        {
            print("Hash file deletion failed:\(error.localizedDescription)")
        }
        
    }
    let resourceFileName = "app-resource"//Resource file name saved within the app
    let resourceFileURL = getDocumentsDirectory().appendingPathComponent(resourceFileName)
    
    if FileManager.default.fileExists(atPath: resourceFileURL.path) {
        do{
            print("Resource file deletion completed:\(resourceFileURL.path)")
            try FileManager.default.removeItem(at: resourceFileURL)
        }catch
        {
            print("Resource file deletion failed:\(error.localizedDescription)")
        }
        
    }
}

//Overwrite the existing Hash text file in the app
func overwriteHashTextFile(fileName:String,content:String)
{
    let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
    
    //Check file existence
    if FileManager.default.fileExists(atPath: fileURL.path)
    {
        do{
            try content.write(to:fileURL, atomically: true, encoding: .utf8)
            print("Hash file overwriting completed:\(fileURL.path)")
        }catch{
            print("Hash file overwriting failed:\(error.localizedDescription)")
        }
        
    }else{
        
    }
}



//Process of unzipping a ZIP resource file
func unzipFile(at sourceURL:URL,to destinaltionURL:URL)
{
    let fileManager = FileManager()
    let unzipFileName = "app-resource"//resource file name
    let unzipedFilePath = destinaltionURL.appendingPathComponent(unzipFileName)//Unzipped resource file URL
    do{
        //Delete previously unzipped files if they exist
        if FileManager.default.fileExists(atPath: unzipedFilePath.path) {
            try FileManager.default.removeItem(at: unzipedFilePath)
            print("Existing unzipped files deleted\(unzipedFilePath)")
            
        }
        
        //Thawing process
        try fileManager.createDirectory(at: destinaltionURL, withIntermediateDirectories: true,attributes:nil)
        try fileManager.unzipItem(at: sourceURL, to: destinaltionURL)
        print("Unzipping completed！\(destinaltionURL)")
        
        
        //Delete the ZIP file if it exists after unzipping it
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            try FileManager.default.removeItem(at: sourceURL)
            print("ZIP file deleted after unzipping")
        }
        
    }catch{
        
        print("An error occurred while unzipping！")
    }
    
}

//resource download
class ResourceDownload{
    
    var downloadSuccessed = false//Whether the download was successful or not
    var downloadFailed:Bool = false//Whether the download failed
    var isTryFirstDownloaded:Bool = false//First download
    var isStartSpeak:Bool = false//Will reading begin?
    
    // Call the file download method when the app starts
    public func startFileDownload() {
        
        _ = CaBotAppModel()
        //self.downloadResult = true
        let hashFileName = "hashFile.txt"//Hash file name saved within the app
        
        // Downloading and parsing hash files
        downloadHashFile() { result in
            switch result {
            case .success(let data):
                var hashValue = ""//hash Value
                //Conversion processing to obtain Hash value
                if let content = String(data: data, encoding: .utf8) {
                    let lines = content.split(separator: "\n")
                    for line in lines {
                        let components = line.split(separator: " ")
                        if components.count == 1
                        {
                            //I was able to get the Hash value
                            hashValue = String(components[0])
                            //Get the app's Document directory
                            let fileURL=getDocumentsDirectory().appendingPathComponent(hashFileName)
                            //If a Hash file exists within the app (when starting the app for the second time)
                            if FileManager.default.fileExists(atPath: fileURL.path)
                            {
                                if let hashFileContent = self.readHashTextFile(fileName: hashFileName ){
                                    
                                    print("File content:\(hashFileContent)")
                                    //The existing Hash value in the app is the same as the Hash value obtained from the server
                                    if hashFileContent == hashValue
                                    {
                                        self.downloadFailed = false
                                        print("MD5 hash matched: \(fileURL)")
                                        //Hash File won't save
                                    }else{//If the existing Hash value in the app is different from the Hash value obtained from the server
                                        print("MD5 hashes don't match: \(fileURL.lastPathComponent)")
                                        //Overwrite Hash file
                                        overwriteHashTextFile(fileName: hashFileName, content: hashValue )
                                        //Save zip file
                                        self.downloadResourceZipFile()
                                    }
                                }else{
                                    print("Failed to get Hash value")
                                }
                            }else{//If there is no Hash file in the app (when starting the app for the first time)
                                //Save new Hash file
                                saveHashTextFile(fileName: hashFileName, content: hashValue)
                                //Save zip file
                                self.downloadResourceZipFile()
                            }
                        }
                    }//for　End
                }//Get hash value　End
            case .failure(let error):
                print("Failed to download hash file：\(error)")
            }
        }
        
    }//startFileDownload end
    
    //Get hash value
    func downloadHashFile(retries: Int = 3,completion: @escaping (Result<Data, Error>) -> Void) {
        let appModel = CaBotAppModel()
        let md5FileURL = URL(string: "http://\(appModel.primaryAddr):9090/map/app-resource-md5")
        self.isTryFirstDownloaded = true
        print("Start obtaining hash value。\(String(describing: md5FileURL))")
        let task = URLSession.shared.dataTask(with: md5FileURL!) { (data, response, error) in
            if !self.downloadSuccessed {
                if error != nil {
                    if retries > 0{
                        print("Download failed. Attempt to retry. Remaining number of retries: \(retries)")
                        deleteHashFile()
                        self.downloadHashFile( retries: retries - 1, completion: completion)
                        if retries == 3{//An error message is read aloud when retrying for the first time.
                            self.isStartSpeak = true
                        }
                    }else{
                        self.downloadFailed = true
                        print("Download failed. Alert UI is displayed:\(self.downloadFailed)")
                        
                        //completion(.failure(error))
                    }
                    
                    return
                }
            }
            
            guard let data = data else {
                let error = NSError(domain: "FileDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(error))
                return
            }
            
            completion(.success(data))
        }
        task.resume()
    }
    
    //Read Hash text file in app
    func readHashTextFile(fileName:String) -> String?{
        
        let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
        do{
            let content = try String(contentsOf:fileURL,encoding: .utf8)
            print("Read Hash file")
            self.downloadSuccessed = true
            self.downloadFailed = false
            return content
            
        }catch{
            print("Reading Hash file failed:\(error.localizedDescription)")
            return nil
        }
    }
    
    //Download resource ZIP file
    public func downloadResourceZipFile()
    {
        let appModel = CaBotAppModel()
        ///Below is the Zip file download process
        ///zip file URL
        //let path = "http://localhost:9090/map/app-resource.zip"
        let path = "http://\(appModel.primaryAddr):9090/map/app-resource.zip"
        
        // Specify the Download folder URL
        let downloadURL = URL(string: (path))!
        // Specify the destination folder URL (here, create the "Downloads" folder in the document directory)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // let savedFolderURL = documentsURL.appendingPathComponent("Downloads")
        self.downloadZipFileFile(from: downloadURL,to:documentsURL) { result in
            switch result {
            case .success(let savedURL):
                unzipFile(at: savedURL, to: documentsURL)
                self.downloadFailed = false
                
                print("Zip file saving completed: \(savedURL)")
            case .failure(let error):
                print("Failed to save zip file: \(error)")
            }
        }
    }
    
    
    
    
    func downloadZipFileFile(from url: URL, to destinationFolderURL: URL,retries:Int = 3, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { (localURL, response, error) in
            guard let localURL = localURL else {
                let error = NSError(domain: "FileDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "File URL is nil"])
                completion(.failure(error))
                return
            }
            
            do {
                let destinationURL = destinationFolderURL.appendingPathComponent(url.lastPathComponent)
                
                //Delete if file already exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Move the downloaded file to the specified folder
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                completion(.success(destinationURL))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
}//Class Resource End



//Display error message and retry button when resource download fails
struct ResourceDownloadRetryUIView :View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State public var isDownloadFinished = false
    @State var resourceDownload = ResourceDownload()
    var body: some View {
        //First time Donwload. Run only once
        if !resourceDownload.isTryFirstDownloaded
        {
            let _: () = resourceDownload.startFileDownload()
        }
        //If ownload fails, an error message and retry will be displayed
        if resourceDownload.downloadFailed
        {
            if resourceDownload.isStartSpeak
            {
                let _ =  print("Error message read out loud: \(resourceDownload.isStartSpeak)")
                let message = CustomLocalizedString("RetryAlert", lang: modelData.resourceLang)
                let _ = modelData.speak(message) {}
                
                let _ = resourceDownload.isStartSpeak = false
            }
            
            Section(header:  Text(CustomLocalizedString("ResourceDownload", lang: modelData.resourceLang))){
                
                Text(CustomLocalizedString("RetryAlert", lang: modelData.resourceLang)).font(.body).foregroundColor(.red).lineLimit(1)
                
                Button(action: {
                    let _: () = resourceDownload.startFileDownload()
                    
                },label: {
                    Text(CustomLocalizedString("Retry", lang: modelData.resourceLang)).foregroundColor(.blue)
                })
            }
        }
    }
}
