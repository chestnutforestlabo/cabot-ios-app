//
//  LogFileDetailView.swift
//  CaBot
//
//  Created by kayukawa on 2023/08/24.
//  Copyright © 2023 Carnegie Mellon University. All rights reserved.
//

import SwiftUI

struct LogFileDetailView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    @State var langOverride:String
    @State var logFileName:String

    @State var inputTitleText = ""
    @State var inputDetailsText = ""

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
            Section(){
                NavigationLink(destination: SubmitBugReportView(
                                    langOverride: modelData.resourceLang,
                                    logFileName: logFileName,
                                    reportTitle: inputTitleText,
                                    reportDetails: inputDetailsText)
                                    .environmentObject(modelData),
                               label: {Text("CHECK_YOUR_REPORT")})
                .disabled(inputTitleText.count==0 || inputDetailsText.count==0)
            }
        }.listStyle(PlainListStyle())
    }
}

struct LogFileDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        modelData.teamID = "test"

        return LogFileDetailView(langOverride: "en-US", logFileName: "")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}
