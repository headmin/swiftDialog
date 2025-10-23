//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKSidebarView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { // infoBox
            VStack {
                LabelView(label: "ck-infobox".localized)
                Text("Use markdown formatting to style the text")
                    .frame(width: .infinity, alignment: .leading)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoBox.present)
                        .toggleStyle(.switch)
                    TextEditor(text: $observedData.args.infoBox.value)
                        .frame(height: 100)
                        .background(Color("editorBackgroundColour"))
                        .border(.primary, width: 0.5)
                }
            }
            VStack {
                LabelView(label: "ck-infotext".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoText.present)
                        .toggleStyle(.switch)
                    TextField("ck-infotext".localized, text: $observedData.args.infoText.value)
                }
            }

        }
        .padding(20)
        Spacer()
    }
}

