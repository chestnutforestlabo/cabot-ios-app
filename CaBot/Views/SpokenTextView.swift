//
//  SpokenTextView.swift
//  CaBot
//
//  Created by Daisuke Sato on 3/15/24.
//  Copyright © 2024 Carnegie Mellon University. All rights reserved.
//

import SwiftUI

struct SpokenTextView: View {
    @EnvironmentObject var modelData: CaBotAppModel

    var body: some View {
        Form {
            ForEach(modelData.userInfo.speakingText, id: \.self) { text in
                SpokenTokenView(speakingText: text)
            }
        }
    }
    
    static func showText(text: SpeakingText) -> some View {
        let texts = text.subTexts()
        return Label {
            HStack {
                Text(texts.0) +
                Text(texts.1)
                    .bold() +
                Text(texts.2)
                    .foregroundColor(.blue) +
                Text(texts.3)
                    .foregroundColor(.gray)
            }
            .border( Color.black, width: 2)
        } icon: {
            Image(systemName: "text.bubble")
        }
    }
}

struct SpokenTokenView: View {
    @ObservedObject var speakingText :SpeakingText
    
    var body: some View {
        let texts = speakingText.subTexts()
        return Label {
            HStack {
                Text(texts.0) +
                Text(texts.1)
                    .bold() +
                Text(texts.2)
                    .foregroundColor(.blue) +
                Text(texts.3)
                    .foregroundColor(.gray)
            }
        } icon: {
            Image(systemName: "text.bubble")
        }
    }
}



#Preview {
    SpokenTextView()
}
