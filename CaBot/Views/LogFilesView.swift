//
//  LogFilesView.swift
//  CaBot
//
//  Created by kayukawa on 2023/08/24.
//  Copyright © 2023 Carnegie Mellon University. All rights reserved.
//

import SwiftUI


struct LogFiles: Codable, Hashable{
    var status: String
    var log_files: [LogFile]
}

struct LogFile: Codable, Hashable{
    var file_name: String
    var is_report_submitted: Bool
    var is_uploaded_to_box: Bool
}

@available(iOS 15.0, *)
struct LogFilesView: View {
    @Environment(\.locale) var locale: Locale
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    @State var langOverride:String
    @State private var isShowingSheet = false
    @State private var selectedLogFile = ""

    var reportTitle = ""
    var reportDetails = ""
    var body: some View {
        // Load log file list from CaBot
        let jsonDataFromCaBot = """
        {
            "status": "OK",
            "log_files": [
                {
                    "file_name": "cabot_2023-9-1-12-00-00",
                    "is_report_submitted": false,
                    "is_uploaded_to_box": false,
                },{
                    "file_name": "cabot_2023-9-1-13-00-00",
                    "is_report_submitted": false,
                    "is_uploaded_to_box": false,
                },{
                    "file_name": "cabot_2023-9-1-15-00-00",
                    "is_report_submitted": false,
                    "is_uploaded_to_box": false,
                }
            ]
        }
        """.data(using: .utf8)!
        var logFiles = try! JSONDecoder().decode(LogFiles.self, from: jsonDataFromCaBot)

        let header = Text("SELECT_LOG")
        return Form{
            Section(header: header){
                ForEach(logFiles.log_files, id: \.self) { logFile in
                    Button(action: {isShowingSheet.toggle()
                        selectedLogFile = logFile.file_name
                    },
                           label: {Text(logFile.file_name)})
                    .sheet(isPresented: $isShowingSheet) {
                        ReportSubmissionForm(langOverride: modelData.resourceLang, logFileName: selectedLogFile)
                            .environmentObject(modelData)
                    }
                }
            }
        }.listStyle(PlainListStyle())
    }
}

@available(iOS 15.0, *)
struct LogFilesView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        modelData.teamID = "test"

        return LogFilesView(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}

@available(iOS 15.0, *)
struct ReportSubmissionForm: View {
    @State var langOverride:String
    let logFileName: String

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var modelData: CaBotAppModel
    @State var inputTitleText = ""
    @State var inputDetailsText = ""
    
    @State private var showingConfirmationAlert = false
    var body: some View {
        return Form{
            Section(
                header: Text(logFileName)){
                    VStack{
                        HStack {
                            Text("REPORT_TITLE")
                            Spacer()
                        }
                        TextField("ENTER_REPORT_TITLE", text: $inputTitleText)
                    }
                }
            Section(){
                VStack{
                    HStack {
                        Text("REPORT_DETAILS")
                        Spacer()
                    }
                    if #available(iOS 16.0, *){
                        TextField("ENTER_REPORT_DETAILS", text: $inputDetailsText, axis: .vertical)
                            .frame(height: 100)
                    }else{
                        TextField("ENTER_REPORT_DETAILS", text: $inputDetailsText)
                            .frame(height: 100)
                    }
                }
            }
            Button(
                action: {
                    self.showingConfirmationAlert = true
                },
                label: {if(modelData.suitcaseConnected){Text("SUBMIT_REPORT")}
                    else{Text("PLEASE_CONNECT_TO_SUITCASE")}
                })
                .disabled(inputTitleText.count==0 || inputDetailsText.count==0 || !modelData.suitcaseConnected)
                .alert(Text("CONFIRM_REPORT_SUBMISSION"), isPresented: $showingConfirmationAlert){
                    Button(role: .destructive,
                           action: {
                            submitReport()
                            dismiss()},
                           label: {Text("SUBMIT")})
                        }
        }
    }
}

func submitReport(){
    
}
