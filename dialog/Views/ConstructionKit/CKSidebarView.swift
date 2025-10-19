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
        VStack { // infoBox
            VStack {
                LabelView(label: "ck-infobox".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoBox.present)
                        .toggleStyle(.switch)
                    TextEditor(text: $observedData.args.infoBox.value)
                        .frame(height: 100)
                        .background(Color("editorBackgroundColour"))
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

