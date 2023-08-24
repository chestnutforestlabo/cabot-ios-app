//
//  SubmitBugReportView.swift
//  CaBot
//
//  Created by kayukawa on 2023/08/24.
//  Copyright © 2023 Carnegie Mellon University. All rights reserved.
//

import SwiftUI

struct SubmitBugReportView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    @State var langOverride:String
    @State var logFileName:String
    @State var reportTitle:String
    @State var reportDetails:String

    @State var inputTitleText = ""
    @State var inputDetailsText = ""

    var body: some View {
        return Form{
            Section(header: Text("Log File")){
                Text(logFileName)
            }
            Section(header:  Text("REPORT_TITLE")){
                HStack {
                    Text(reportTitle)
                    Spacer()
                }
            }
            Section(header: Text("REPORT_DETAILS")){
                Text(reportDetails)
            }
            Section(){
                NavigationLink(destination: MainMenuView().environmentObject(modelData),
                    label: {Button(action: {submitReport()}) {Text("SUBMIT_REPORT")}}
                )
            }
        }
    }

    func submitReport(){
        // Code for submitting the report and log files
    }
}

struct SubmitBugReportView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        modelData.teamID = "test"

        return SubmitBugReportView(langOverride: "en-US",
                                   logFileName: "",
                                   reportTitle: "",
                                   reportDetails: "")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}
