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
    @EnvironmentObject var modelData: LogReportModel

    @State var langOverride:String
    @State private var isShowingSheet = false

    var reportTitle = ""
    var reportDetails = ""
    var body: some View {
        if modelData.isListReady {
            Form{
                Section(header: Text("SELECT_LOG")){
                    ForEach($modelData.log_list, id: \.self) { log_entry in
                    Button(action: {
                            isShowingSheet = true
                            modelData.requestDetail(log: log_entry.wrappedValue)
                        },
                               label: {
                            HStack {
                                Text(log_entry.wrappedValue.logDate(for: locale.identifier))
                                
                                Spacer()
                                if log_entry.wrappedValue.is_uploaded_to_box ?? false {
                                    Image(systemName: "shippingbox")
                                } else {
                                    Image(systemName: "newspaper.circle").disabled(!(log_entry.wrappedValue.is_report_submitted ?? false))
                                }
                            }
                        })
                        .sheet(isPresented: $isShowingSheet) {
                            NavigationView {
                                ReportSubmissionForm(langOverride: locale.identifier)
                                    .environmentObject(modelData)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .onDisappear() {
                modelData.clear()
            }
        } else {
            ProgressView()
                .onAppear() {
                    modelData.clear()
                    modelData.refreshLogList()
                }
        }
    }
}

@available(iOS 15.0, *)
struct LogFilesView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = LogReportModel()
        modelData.set(list: [LogEntry(name: "cabot_2023-08-30-12-00-00")])
        modelData.set(detail: LogEntry(name: "cabot_2023-08-30-12-00-00", title: "This is a test title", detail: "This is a test detail text"))

        let appModel = CaBotAppModel()
        appModel.suitcaseConnected = true
        modelData.delegate = appModel

        return LogFilesView(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}


@available(iOS 15.0, *)
struct ReportSubmissionFor_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = LogReportModel()
        modelData.set(list: [LogEntry(name: "cabot_2023-08-30-12-00-00")])
        modelData.set(detail: LogEntry(name: "cabot_2023-08-30-12-00-00", title: "This is a test title", detail: "This is a test detail text"))
        modelData.status = .OK

        let appModel = CaBotAppModel()
        appModel.suitcaseConnected = true
        modelData.delegate = appModel

        return ReportSubmissionForm(langOverride: "en-US")
            .environmentObject(modelData)
            .environment(\.locale, Locale.init(identifier: "en-US"))
    }
}

public extension Text {
    func sectionHeaderStyle() -> some View {
        self
            .font(.system(.title3))
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .textCase(nil)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}

@available(iOS 15.0, *)
struct ReportSubmissionForm: View {
    @State var langOverride:String

    @Environment(\.dismiss) var dismiss
    @State private var showingConfirmationAlert = false
    @EnvironmentObject var modelData: LogReportModel
    //@State var inputTitleText: String
    //@State var inputDetailsText: String
    
    var body: some View {
        VStack {
            if modelData.isDetailReady {
                Form {
                    Section(header: Text(modelData.selectedLog.name).sectionHeaderStyle()){
                        VStack{
                            HStack {
                                Text("REPORT_TITLE").bold()
                                Spacer()
                            }
                            TextField("ENTER_REPORT_TITLE", text: .bindOptional($modelData.selectedLog.title, ""))
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 0.25)
                                )
                        }
                    }
                    .headerProminence(.increased)
                    Section(){
                        VStack{
                            HStack {
                                Text("REPORT_DETAILS").bold()
                                Spacer()
                            }
                            TextEditor(text: .bindOptional($modelData.selectedLog.detail, ""))
                                .frame(minHeight: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 0.25)
                                )
                        }
                    }
                    if !(modelData.selectedLog.is_uploaded_to_box ?? false) {
                        Section() {
                            Button {
                                dismiss()
                                modelData.submit(log: modelData.selectedLog)
                            } label: {
                                if modelData.selectedLog.is_report_submitted ?? false {
                                    Text("UPDATE_REPORT").bold()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text("SUBMIT_REPORT").bold()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .disabled(!modelData.isDetailModified || !modelData.isOkayToSubmit)
                            if !modelData.isOkayToSubmit{
                                if modelData.isSuitcaseConnected {
                                    Text("SUITCASE_DOES_NOT_ACCEPT_NEW_REPORT")
                                        .foregroundColor(.red)
                                } else {
                                    Text("PLEASE_CONNECT_TO_SUITCASE")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        Text("REPORT_IS_UPLOADED")
                    }
                }
                /*
                 .onTapGesture {
                 let keyWindow = UIApplication.shared.connectedScenes
                 .filter({$0.activationState == .foregroundActive})
                 .map({$0 as? UIWindowScene})
                 .compactMap({$0})
                 .first?.windows
                 .filter({$0.isKeyWindow}).first
                 keyWindow?.endEditing(true)
                 }*/
            } else {
                ProgressView()
            }
        }
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing) {
                Button {
                    if modelData.isDetailModified {
                        self.showingConfirmationAlert = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .alert(Text("CONFIRM_DISCARD_SUBMISSION"), isPresented: $showingConfirmationAlert){
                    Button(role: .destructive,
                           action: {
                        dismiss()
                    }, label: {
                        Text("Yes")
                    })
                }
            }
        }
    }
}

// https://stackoverflow.com/questions/70695562/how-to-convert-bindingstring-to-bindingstring-in-swiftui
extension Binding where Value: Equatable {
    
    
    /// Given a binding to an optional value, creates a non-optional binding that projects
    /// the unwrapped value. If the given optional binding contains `nil`, then the supplied
    /// value is assigned to it before the projected binding is generated.
    ///
    /// This allows for one-line use of optional bindings, which is very useful for CoreData types
    /// which are non-optional in the model schema but which are still declared nullable and may
    /// be nil at runtime before an initial value has been set.
    ///
    ///     class Thing: NSManagedObject {
    ///         @NSManaged var name: String?
    ///     }
    ///     struct MyView: View {
    ///         @State var thing = Thing(name: "Bob")
    ///         var body: some View {
    ///             TextField("Name", text: .bind($thing.name, ""))
    ///         }
    ///     }
    ///
    /// - note: From experimentation, it seems that a binding created from an `@State` variable
    /// is not immediately 'writable'. There is seemingly some work done by SwiftUI following the render pass
    /// to make newly-created or assigned bindings modifiable, so simply assigning to
    /// `source.wrappedValue` inside `init` is not likely to have any effect. The implementation
    /// has been designed to work around this (we don't assume that we can unsafely-unwrap even after
    /// assigning a non-`nil` value), but a side-effect is that if the binding is never written to outside of
    /// the getter, then there is no guarantee that the underlying value will become non-`nil`.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    static func bindOptional(_ source: Binding<Value?>, _ defaultValue: Value) -> Binding<Value> {
        self.init(get: {
            source.wrappedValue ?? defaultValue
        }, set: {
            source.wrappedValue = ($0 as? String) == "" ? nil : $0
        })
    }
}
