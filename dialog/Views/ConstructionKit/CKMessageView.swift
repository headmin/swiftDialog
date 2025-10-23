LabelView(label: "ck-message".localized)
            HStack {
                Picker("ck-textalignmnet".localized, selection: $observedData.args.messageAlignment.value) {
                    Text("").tag("")
                    ForEach(appDefaults.allignmentStates.keys.sorted(), id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: observedData.args.messageAlignment.value) { _, state in
                    observedData.appProperties.messageAlignment = appDefaults.allignmentStates[state] ?? .leading
                    observedData.args.messageAlignment.present = true
                }
                Toggle("ck-verticalposition".localized, isOn: $observedData.args.messageVerticalAlignment.present)
                    .toggleStyle(.switch)
                ColorPicker("ck-colour".localized,selection: $observedData.appProperties.messageFontColour)
                Button("ck-reset".localized) {
                    observedData.appProperties.messageFontColour = .primary
                }
            }
            TextEditor(text: $observedData.args.messageOption.value)
                .frame(minHeight: 50)
                .background(Color("editorBackgroundColour"))