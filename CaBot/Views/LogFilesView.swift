//
//  LogFilesView.swift
//  CaBot
//
//  Created by kayukawa on 2023/08/24.
//  Copyright © 2023 Carnegie Mellon University. All rights reserved.
//

import SwiftUI


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
        let logFileList = ["cabot_2023-9-1-12-00-00","cabot_2023-9-1-13-00-00","cabot_2023-9-1-14-00-00"]
        let header = Text("SELECT_LOG")
        return Form{
            Section(header: header){
                ForEach(logFileList, id: \.self) { logFile in
                    Button(action: {isShowingSheet.toggle()
                        selectedLogFile = logFile
                    },
                           label: {Text(logFile)})
                    .sheet(isPresented: $isShowingSheet) {
                        ReportSubmissionForm(langOverride: modelData.resourceLang, logFileName: selectedLogFile)
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
                })
                {Text("SUBMIT_REPORT")}
                .disabled(inputTitleText.count==0 || inputDetailsText.count==0)
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
