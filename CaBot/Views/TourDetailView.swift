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

struct TourDetailView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel
    @State private var isConfirming = false
    @State private var targetTour: TourProtocol?

    var tour: TourProtocol
    var showStartButton: Bool = true
    var showCancelButton: Bool = false

    var body: some View {
        let tourManager = modelData.tourManager

        Form {
            Text(tour.title)
                .font(Font.custom("", size: 24.0, relativeTo: .title))
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)

            if showStartButton {
                Button(action: {
                    if tourManager.hasDestination {
                        targetTour = tour
                        isConfirming = true
                    } else {
                        // if there is no destination, start immediately
                        tourManager.set(tour: tour)
                        tourManager.nextDestination()
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Label{
                        Text("START_TOUR")
                    } icon: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                }
                .padding()
                .actionSheet(isPresented: $isConfirming) {
                    let message = String(format: NSLocalizedString("ADD_TOUR_MESSAGE", comment: ""),
                                         arguments: [modelData.tourManager.destinationCount])
                    return ActionSheet(title: Text("ADD_TOUR"),
                                       message: Text(message),
                                       buttons: [
                                        .cancel(),
                                        .destructive(
                                            Text("OVERWRITE_TOUR"),
                                            action: {
                                                if let tour = targetTour {
                                                    tourManager.set(tour: tour)
                                                    tourManager.nextDestination()
                                                    presentationMode.wrappedValue.dismiss()
                                                    targetTour = nil
                                                }
                                            }
                                        )
                                       ])
                }
            }
            if let cd = tour.currentDestination {
                Label(cd.title, systemImage: "arrow.triangle.turn.up.right.diamond")
            }

            ForEach(tour.destinations, id: \.self) { dest in
                Label(dest.title, systemImage: "mappin.and.ellipse")
            }

            if showCancelButton {
                Button(action: {
                    isConfirming = true
                }) {
                    Label{
                        Text("CANCEL_NAVIGATION")
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                }
                .actionSheet(isPresented: $isConfirming) {
                    let message = String(format: NSLocalizedString("CANCEL_NAVIGATION_MESSAGE", comment: ""),
                                         arguments: [modelData.tourManager.destinationCount])
                    return ActionSheet(title: Text("CANCEL_NAVIGATION"),
                                       message: Text(message),
                                       buttons: [
                                        .cancel(),
                                        .destructive(
                                            Text("CANCEL_ALL"),
                                            action: {
                                                modelData.tourManager.clearAll()
                                                presentationMode.wrappedValue.dismiss()
                                            }
                                        )
                                       ]
                    )
                }
            }
        }
    }
}

struct TourDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resource(by: "place0")!
        let tours = try! Tours(at: resource.toursURL!)

        return TourDetailView(tour: tours.list[0],
                              showStartButton: true,
                              showCancelButton: true
                              )
            .environmentObject(modelData)
    }
}
