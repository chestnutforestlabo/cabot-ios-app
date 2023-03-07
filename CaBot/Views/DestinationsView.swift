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

import SwiftUI

struct DestinationsView: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State private var isConfirming = false
    @State private var targetDestination: Destination?

    var src: Source
    var destination: Destination?

    var body: some View {
        let tourManager = modelData.tourManager
        let destinations = try! Destination.load(at: src)
        var header: Text?
        if let title = destination?.title {
            header = Text(title.text)
        } else {
            header = Text("SELECT_DESTINATION")
        }

        return Form {
            Section(
                header: header) {
                ForEach(destinations, id: \.self) { destination in
                    if let error = destination.error {
                        HStack{
                            Text(destination.title.text)
                            Text(error).font(.system(size: 11))
                        }.foregroundColor(Color.red)
                    } else if let src = destination.file {
                        NavigationLink(
                            destination: DestinationsView(src: src, destination: destination)
                                .environmentObject(modelData),
                            label: {
                                Text(destination.title.text)
                                    .accessibilityLabel(destination.title.pron)
                            })
                    } else {
                        if let _ = destination.message {
                            NavigationLink(
                                destination: DestinationDetailView(destination: destination)
                                    .environmentObject(modelData),
                                label: {
                                    Text(destination.title.text)
                                        .accessibilityLabel(destination.title.pron)
                                })
                        } else {
                            Button(action: {
                                if modelData.tourManager.hasDestination {
                                    targetDestination = destination
                                    isConfirming = true
                                } else {
                                    // if there is no destination, start immediately
                                    tourManager.addToLast(destination: destination)
                                    modelData.needToStartAnnounce(wait: true)
                                    NavigationUtil.popToRootView()
                                }
                            }){
                                Text(destination.title.text)
                                    .accessibilityLabel(destination.title.pron)
                            }
                            // deprecated
                            .actionSheet(isPresented: $isConfirming) {
                                let message = LocalizedStringKey("ADD_A_DESTINATION_MESSAGE \(modelData.tourManager.destinationCount, specifier: "%d")")
                                return ActionSheet(title: Text("ADD_A_DESTINATION"),
                                            message: Text(message),
                                            buttons: [
                                                .cancel(),
                                                .destructive(
                                                    Text("CLEAR_ALL_THEN_ADD"),
                                                    action: {
                                                        if let dest = targetDestination {
                                                            tourManager.clearAll()
                                                            tourManager.addToLast(destination: dest)
                                                            targetDestination = nil
                                                            NavigationUtil.popToRootView()
                                                        }
                                                    }
                                                ),
                                                .default(
                                                    Text("ADD_TO_FIRST"),
                                                    action: {
                                                        if let dest = targetDestination {
                                                            tourManager.stopCurrent()
                                                            tourManager.addToFirst(destination: dest)
                                                            targetDestination = nil
                                                            NavigationUtil.popToRootView()
                                                        }
                                                    }
                                                ),
                                                .default(
                                                    Text("ADD_TO_LAST"),
                                                    action: {
                                                        if let dest = targetDestination {
                                                            tourManager.addToLast(destination: dest)
                                                            targetDestination = nil
                                                            NavigationUtil.popToRootView()
                                                        }
                                                    }
                                                )
                                            ]
                                )
                            }
                        }

                        /* for iOS 15
                             .confirmationDialog("ADD_DESTINATION", isPresented: , presenting: targetDestination) {
                             detail in
                            Button {

                            } label: {
                                Text("Cancel Current")
                            }
                            Button("Cancel", role: .cancel) {
                                targetDestination = nil
                            }
                        } message: { detail in

                        }
                        */
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }

}

struct DestinationsView_Previews: PreviewProvider {
    static var previews: some View {
        preview2
        preview1
    }

    static var preview1: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resource(by: "place0")!

        return DestinationsView(src: resource.destinationsSource!)
            .environmentObject(modelData)
    }

    static var preview2: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resource(by: "place0")!

        let destinations = try! Destination.load(at: resource.destinationsSource!)

        return DestinationsView(src: destinations[0].file!)
            .environmentObject(modelData)
    }
}
