//
//  CKDataEntryView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKDataEntryView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    //@State var textfieldContent: [TextFieldState]

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        //textfieldContent = userInputState.textFields
    }

    var body: some View {
        ScrollView {
            HStack {
                Toggle("Format output as JSON", isOn: $observedData.args.jsonOutPut.present)
                .toggleStyle(.switch)
                Spacer()
            }
            LabelView(label: "ck-textfields".localized)
            HStack {
                Button(action: {
                    userInputState.textFields.append(TextFieldState(title: ""))
                    observedData.textFieldArray.append(TextFieldState(title: ""))
                    observedData.args.textField.present = true
                    appArguments.textField.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("ck-show".localized, isOn: $observedData.args.textField.present)
                    .toggleStyle(.switch)

                //Button("Clear All") {
                //    observedData.listItemPresent = false
                //    observedData.listItemsArray = [ListItems]()
                //}

                Spacer()
            }

            ForEach(0..<userInputState.textFields.count, id: \.self) { item in
                HStack {
                    Button(action: {
                        guard item >= 0 && item < observedData.textFieldArray.count else {
                            writeLog("Could not delete textfield at position \(item)", logLevel: .info)
                            return
                        }
                        writeLog("Delete textfield at position \(item)", logLevel: .info)
                        userInputState.textFields.remove(at: item)
                        observedData.textFieldArray.remove(at: item)
                    }, label: {
                        Image(systemName: "trash")
                    })
                    
                    Toggle("ck-required".localized, isOn: $observedData.textFieldArray[item].required)
                        .onChange(of: observedData.textFieldArray[item].required) { _, textRequired in
                            observedData.requiredFieldsPresent.toggle()
                            userInputState.textFields[item].required = textRequired
                        }
                        .toggleStyle(.switch)
                    Toggle("ck-secure".localized, isOn: $observedData.textFieldArray[item].secure)
                        .onChange(of: observedData.textFieldArray[item].secure) { _, textSecure in
                            userInputState.textFields[item].secure = textSecure
                        }
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    TextField("ck-title".localized, text: $observedData.textFieldArray[item].title)
                        .onChange(of: observedData.textFieldArray[item].title) { _, textTitle in
                            userInputState.textFields[item].title = textTitle
                        }
                    TextField("ck-value".localized, text: $observedData.textFieldArray[item].value)
                        .onChange(of: observedData.textFieldArray[item].value) { _, textValue in
                            userInputState.textFields[item].value = textValue
                        }
                    TextField("ck-prompt".localized, text: $observedData.textFieldArray[item].prompt)
                        .onChange(of: observedData.textFieldArray[item].prompt) { _, textPrompt in
                            userInputState.textFields[item].prompt = textPrompt
                        }
                }
                .padding(.leading, 20)
                HStack {
                    TextField("ck-regex".localized, text: $observedData.textFieldArray[item].regex)
                        .onChange(of: observedData.textFieldArray[item].regex) { _, textRegex in
                            userInputState.textFields[item].regex = textRegex
                        }
                    TextField("ck-regexerror".localized, text: $observedData.textFieldArray[item].regexError)
                        .onChange(of: observedData.textFieldArray[item].regexError) { _, textRegexError in
                            userInputState.textFields[item].regexError = textRegexError
                        }
                }
                .padding(.leading, 20)
                Divider()
            }
            LabelView(label: "ck-select".localized)

            LabelView(label: "ck-checkbox".localized)
            Spacer()
        }
        .padding(20)
    }
}

