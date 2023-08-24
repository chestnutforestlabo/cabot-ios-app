//
//  LogFilesView.swift
//  CaBot
//
//  Created by kayukawa on 2023/08/24.
//  Copyright © 2023 Carnegie Mellon University. All rights reserved.
//

import SwiftUI

struct LogFilesView: View {
    @Environment(\.locale) var locale: Locale
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    @State var langOverride:String

    var body: some View {
        // Load log file list from CaBot
        let logFileList = ["cabot_2023-9-1-12-00-00","cabot_2023-9-1-13-00-00","cabot_2023-9-1-14-00-00"]
        let header = Text("SELECT_LOG")

        return Form{
            Section(
                header: header){
                    ForEach(logFileList, id: \.self) { logFile in
                        NavigationLink(
                            destination: LogFileDetailView(langOverride: modelData.resourceLang, logFileName: logFile)
                                .environmentObject(modelData),
                            label:{Text(logFile)
                            }
                        )
                    }
                }
        }.listStyle(PlainListStyle())
    }
}

struct LogFilesView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        modelData.teamID = "test"

        return LogFilesView(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}
