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
import HLPDialog

struct ConversationView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var modelData: CaBotAppModel

    let REQUEST_START_NAVIGATION:Notification.Name = Notification.Name(rawValue:"request_start_navigation")

    var src: Source?
    var dsrc: Source?

    class Observer {
        static var shared: Observer? = nil
        let owner:ConversationView

        static func getInstance(owner: ConversationView) -> Observer {
            Observer.shared = Observer(owner: owner)
            return Observer.shared!
        }
        init(owner: ConversationView) {
            self.owner = owner
        }
        @objc func request_start_navigation(note: Notification) {
            NavigationUtil.popToRootView()
//            owner.modelData.needToStartAnnounce(wait: true) TODO: Modify needToStartAnnounce to announce the destination

            DispatchQueue.main.async {
                self.owner.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    func makeUIViewController(context: Context) -> DialogViewController {
        // put dummy config for local converstation
        
        DialogManager.sharedManager().config = [
            "conv_server": "\(modelData.primaryAddr):5050",
            "conv_api_key": "hoge",
            "conv_client_id": "cabot-app"
        ]
        DialogManager.sharedManager().useHttps = false;

        let view = DialogViewControllerCabot()
        view.baseHelper = modelData.dialogViewHelper
        view.tts = modelData.tts

        let observer = Observer.getInstance(owner:self)
        NotificationCenter.default.addObserver(observer,
                                               selector: #selector(Observer.request_start_navigation),
                                               name: REQUEST_START_NAVIGATION, object: nil)

        return view
    }

    func updateUIViewController(_ uiViewController: DialogViewController, context: Context) {
    }

}

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        let modelData = CaBotAppModel()

        let resource = modelData.resourceManager.resources[0]
        ConversationView(src: resource.conversationSource!)
    }
}
