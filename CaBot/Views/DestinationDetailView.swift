// please remove this line
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

struct DestinationDetailView: View {
    @EnvironmentObject var modelData: CaBotAppModel
    @State var destination: Destination
    @State private var isConfirming = false
    @State private var targetDestination: Destination?

    var body: some View {
        let tourManager = modelData.tourManager
        Form {
            Section(header: Text(destination.title.text)) {
                if let startMessage =  destination.startMessage?.content {
                    Text(startMessage)
                }
                if let arriveMessages = destination.arriveMessages{
                    ForEach(arriveMessages, id: \.self) { arriveMessage in
                        Text(arriveMessage.content!)
                    }
                }
                if let url = destination.content?.url {
                    Button("Show more detail") {
                        modelData.contentURL = url
                        modelData.isContentPresenting = true
                    }
                }
                if modelData.modeType == .Normal {
                    Button("Add to destinations") {
                        if modelData.tourManager.hasDestination {
                            targetDestination = destination
                            isConfirming = true
                        } else {
                            // if there is no destination, start immediately
                            tourManager.addToLast(destination: destination)
                            modelData.needToStartAnnounce(wait: true)
                            NavigationUtil.popToRootView()
                        }
                    }
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
                } else {
                    Button(action: {
                        targetDestination = destination
                        isConfirming = true
                    }){
                        Text("SEND_DESTINATION")
                    }
                    .actionSheet(isPresented: $isConfirming) {
                        let message = LocalizedStringKey("SEND_DESTINATION_MESSAGE \(targetDestination!.title.text)")
                        return ActionSheet(title: Text("SEND_DESTINATION"),
                                           message: Text(message),
                                           buttons: [
                                            .cancel(),
                                            .destructive(
                                                Text("CLEAR_AND_ADD_DESTINATION"),
                                                action: {
                                                    if let destination = targetDestination {
                                                        modelData.share(destination: destination)
                                                        NavigationUtil.popToRootView()
                                                        targetDestination = nil
                                                    }
                                                }
                                            ),
                                            .destructive(
                                                Text("ADD_DESTINATION"),
                                                action: {
                                                    if let destination = targetDestination {
                                                        modelData.share(destination: destination, clear: false)
                                                        NavigationUtil.popToRootView()
                                                        targetDestination = nil
                                                    }
                                                }
                                            )
                                           ])
                    }
                }
            }
        }
    }
}

struct DestinationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resource(by: "Test data")!
        let destinations = try! Destination.load(at: resource.destinationsSource!)
        let destination = destinations[0]
        let destinations2 = try! Destination.load(at: destination.file!)

        DestinationDetailView(destination: destinations2[0])
            .environmentObject(modelData)
    }
}
