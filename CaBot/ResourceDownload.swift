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

//ドキュメントディレクトリ取得
func getDocumentsDirectory() -> URL{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return paths
}

//アプリ内にHashファイルが存在しないので、初回保存
func saveHashTextFile(fileName:String,content:String)
{
    let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
    
    //ファイルの存在をチェック
    if FileManager.default.fileExists(atPath: fileURL.path)
    {
        //何もしない
    }else{//ファイルが存在しない場合、新規作成
        do{
            try content.write(to:fileURL, atomically: true, encoding: .utf8)
            print("Hashファイルの保存が完了しました:\(fileURL.path)")
        }catch{
            print("Hashファイルの保存が失敗しました:\(error.localizedDescription)")
        }
    }
}

//リトライの際に、ハッシュファイルを削除する
func deleteHashFile()
{
    let hashFileName = "hashFile.txt"//アプリ内に保存するHashファイル名前
    let hashFileURL = getDocumentsDirectory().appendingPathComponent(hashFileName)
    //すでにファイルが存在する場合は削除
    if FileManager.default.fileExists(atPath: hashFileURL.path) {
        do{
            print("Hashファイルの削除が完了しました:\(hashFileURL.path)")
            try FileManager.default.removeItem(at: hashFileURL)
        }catch
        {
            print("Hashファイルの削除が失敗しました:\(error.localizedDescription)")
        }
      
   }
    let resourceFileName = "app-resource"//アプリ内に保存するリソースファイル名前
    let resourceFileURL = getDocumentsDirectory().appendingPathComponent(resourceFileName)
    
    if FileManager.default.fileExists(atPath: resourceFileURL.path) {
        do{
            print("リソースファイルの削除が完了しました:\(resourceFileURL.path)")
            try FileManager.default.removeItem(at: resourceFileURL)
        }catch
        {
            print("リソースファイルの削除が失敗しました:\(error.localizedDescription)")
        }
      
   }
}

//アプリ内に既存Hashテキストファイルに上書き
func overwriteHashTextFile(fileName:String,content:String)
{
    let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
    
    //ファイルの存在をチェック
    if FileManager.default.fileExists(atPath: fileURL.path)
    {
        do{
            try content.write(to:fileURL, atomically: true, encoding: .utf8)
            print("Hashファイルの上書きが完了しました:\(fileURL.path)")
        }catch{
            print("Hashファイルの上書きが失敗しました:\(error.localizedDescription)")
        }
            
    }else{//ファイルが存在しない場合、新規作成
     
    }
}



//ZIPリソースファイルを解凍する処理
func unzipFile(at sourceURL:URL,to destinaltionURL:URL)
{
    let fileManager = FileManager()
    let unzipFileName = "app-resource"//リソースファイル名
    let unzipedFilePath = destinaltionURL.appendingPathComponent(unzipFileName)//解凍したリソースファイルURL
    do{
        //以前に解凍したファイルが存在する場合は削除
        if FileManager.default.fileExists(atPath: unzipedFilePath.path) {
           try FileManager.default.removeItem(at: unzipedFilePath)
            print("既存の解凍したファイルが削除しました\(unzipedFilePath)")
            
       }
        
        //解凍処理
        try fileManager.createDirectory(at: destinaltionURL, withIntermediateDirectories: true,attributes:nil)
        try fileManager.unzipItem(at: sourceURL, to: destinaltionURL)
        print("解凍が完了しました！\(destinaltionURL)")
       
        
        //解凍した後ZIPファイルが存在する場合は削除
        if FileManager.default.fileExists(atPath: sourceURL.path) {
           try FileManager.default.removeItem(at: sourceURL)
            print("解凍した後ZIPファイルが削除しました")
       }
       
    }catch{
        
        print("解凍中にエラーが発生しました！")
    }
    
}

//リソースダウンロード
 class ResourceDownload{
    
    var downloadSuccessed = false//Downloadが成功かどうか
    var downloadFailed:Bool = false//Downloadが失敗かどうか
    var isTryFirstDownloaded:Bool = false//初回目のDownload
    var isStartSpeak:Bool = false//読み上げが始まるか
     
    // アプリ開始の際にファイルダウンロードのメソッドを呼び出す
    public func startFileDownload() {
        
        _ = CaBotAppModel()
        //self.downloadResult = true
        let hashFileName = "hashFile.txt"//アプリ内に保存するHashファイル名前
       
        // ハッシュファイルのダウンロードと解析
        downloadHashFile() { result in
            switch result {
            case .success(let data):
                var hashValue = ""//hash値
                //Hash値取得のため、変換処理
                if let content = String(data: data, encoding: .utf8) {
                    let lines = content.split(separator: "\n")
                    for line in lines {
                        let components = line.split(separator: " ")
                        if components.count == 1
                        {
                            //Hash値が取得できました
                            hashValue = String(components[0])
                            //アプリのDocumentディレクトリ取得
                            let fileURL=getDocumentsDirectory().appendingPathComponent(hashFileName)
                            //アプリ内にHashファイルが存在している場合（アプリを二回目で起動する場合）
                            if FileManager.default.fileExists(atPath: fileURL.path)
                            {
                                if let hashFileContent = self.readHashTextFile(fileName: hashFileName ){
                                        
                                    print("File content:\(hashFileContent)")
                                    //アプリ内に既存Hash値がサーバーから取得したHash値と同じ
                                    if hashFileContent == hashValue
                                    {
                                        self.downloadFailed = false
                                        print("MD5ハッシュが一致しました: \(fileURL)")
                                        //Hashファイルが保存しない
                                        }else{//アプリ内に既存Hash値がサーバーから取得したHash値と違う場合
                                            print("MD5ハッシュが一致しません: \(fileURL.lastPathComponent)")
                                            //Hashファイルに上書き
                                            overwriteHashTextFile(fileName: hashFileName, content: hashValue )
                                            //Zipファイル保存
                                            self.downloadResourceZipFile()
                                        }
                                    }else{
                                        print("Hash値の取得が失敗しました")
                                    }
                                }else{//アプリ内にHashファイルが存在しない場合（アプリを初回目で起動する場合）
                                    //新しいHashファイル保存
                                    saveHashTextFile(fileName: hashFileName, content: hashValue)
                                    //Zipファイル保存
                                    self.downloadResourceZipFile()
                                }
                            }
                        }//for文　End
                    }//ハッシュ値取得　End
                case .failure(let error):
                    print("ハッシュファイルのダウンロードに失敗しました：\(error)")
                }
            }
    
    }//startFileDownload end
    
    //ハッシュ値取得
    func downloadHashFile(retries: Int = 3,completion: @escaping (Result<Data, Error>) -> Void) {
        let appModel = CaBotAppModel()
        let md5FileURL = URL(string: "http://\(appModel.primaryAddr):9090/map/app-resource-md5")
        self.isTryFirstDownloaded = true
        print("ハッシュ値取得開始。\(String(describing: md5FileURL))")
        let task = URLSession.shared.dataTask(with: md5FileURL!) { (data, response, error) in
            if !self.downloadSuccessed {
                if error != nil {
                    if retries > 0{
                        print("ダウンロードに失敗しました。リトライを試みます。残りリトライ回数: \(retries)")
                        deleteHashFile()
                        self.downloadHashFile( retries: retries - 1, completion: completion)
                        if retries == 3{//初回リトライの際にエラーメッセージが読み上げ
                            self.isStartSpeak = true
                        }
                    }else{
                        self.downloadFailed = true
                        print("AAAダウンロードに失敗しました。アラートUIが表示される:\(self.downloadFailed)")
                      
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
    
    //アプリ内のHashテキストファイルを読み取る
    func readHashTextFile(fileName:String) -> String?{
        
        let fileURL=getDocumentsDirectory().appendingPathComponent(fileName)
        do{
            let content = try String(contentsOf:fileURL,encoding: .utf8)
            print("Hashファイルが読み取りました")
            self.downloadSuccessed = true
            self.downloadFailed = false
            return content
            
        }catch{
            print("Hashファイルの読み取りが失敗しました:\(error.localizedDescription)")
            return nil
        }
    }
    
    //リソースZIPファイルをダウンロードする
    public func downloadResourceZipFile()
    {
        let appModel = CaBotAppModel()
        ///以下はZipファイルダウンロード処理
        ///zipファイルのURL
        //let path = "http://localhost:9090/map/app-resource.zip"
        let path = "http://\(appModel.primaryAddr):9090/map/app-resource.zip"
        
        // DownloadのフォルダURLを指定
        let downloadURL = URL(string: (path))!
        // 保存先のフォルダURLを指定（ここではドキュメントディレクトリ内の "Downloads" フォルダを作成）
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
       // let savedFolderURL = documentsURL.appendingPathComponent("Downloads")
        self.downloadZipFileFile(from: downloadURL,to:documentsURL) { result in
            switch result {
            case .success(let savedURL):
                unzipFile(at: savedURL, to: documentsURL)
                self.downloadFailed = false
                
                print("Zipファイルの保存が完了しました: \(savedURL)")
            case .failure(let error):
                print("Zipファイルの保存に失敗しました: \(error)")
            }
        }
    }
    
    
    
    
    func downloadZipFileFile(from url: URL, to destinationFolderURL: URL,retries:Int = 3, completion: @escaping (Result<URL, Error>) -> Void) {
           let task = URLSession.shared.downloadTask(with: url) { (localURL, response, error) in
              /* if let error = error {
                   if retries > 0{
                       print("ダウンロードに失敗しました。リトライを試みます。残りリトライ回数: \(retries)")
                       //self.downloadFile(from: url, to: destinationFolderURL,retries:retries - 1, completion: completion)
                   }else{
                       self.isTryFirstDownloaded = true
                       self.downloadFailed = true
                       completion(.failure(error))
                   }
                   
                   return
               }*/
               
               guard let localURL = localURL else {
                   let error = NSError(domain: "FileDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "File URL is nil"])
                   completion(.failure(error))
                   return
               }
               
               do {
                   let destinationURL = destinationFolderURL.appendingPathComponent(url.lastPathComponent)
                   
                    //すでにファイルが存在する場合は削除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                       try FileManager.default.removeItem(at: destinationURL)
                   }
                   
                   // ダウンロードしたファイルを指定のフォルダに移動
                   try FileManager.default.moveItem(at: localURL, to: destinationURL)
                   completion(.success(destinationURL))
               } catch {
                   completion(.failure(error))
               }
           }
           task.resume()
       }
    
}//Class Resource End



//リソースダウンロード失敗際にエラーメッセージとリトライボタン表示
struct ResourceDownloadRetryUIView :View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State public var isDownloadFinished = false
    @State var resourceDownload = ResourceDownload()
    var body: some View {
        //初回目Donwload。1回のみ実行
        if !resourceDownload.isTryFirstDownloaded
        {
            let _: () = resourceDownload.startFileDownload()
        }
        //Downloadが失敗したら、エラーメッセージとリトライが表示する
        if resourceDownload.downloadFailed
        {
            //エラ〜メッセージが読み上げ
            if resourceDownload.isStartSpeak
            {
                let _ =  print("エラ〜メッセージが読み上げ: \(resourceDownload.isStartSpeak)")
                let message = CustomLocalizedString("RetryAlert", lang: modelData.resourceLang)
                let _ = modelData.speak(message) {}
                   
                let _ = resourceDownload.isStartSpeak = false
            }
            
            Section(header:  Text("RetryAlert").font(.caption2).foregroundColor(.red).lineLimit(1)){
                Button(action: {
                    let _: () = resourceDownload.startFileDownload()
                    
                },label: {
                    Text("Retry").foregroundColor(.blue)
                })
            }
        }
    }
}
