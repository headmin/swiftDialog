//
//  DropdownView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 2/6/21.
//

import Foundation
import SwiftUI
import Combine


struct DropdownView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var selectedOption: [String]

    var fieldwidth: CGFloat = 0

    var dropdownCount = 0

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue()
        } else {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue() - observedDialogContent.args.iconSize.value.floatValue()
        }

        var defaultOptions: [String] = []
        for index in 0..<userInputState.dropdownItems.count {
            defaultOptions.append(userInputState.dropdownItems[index].defaultValue)
            if userInputState.dropdownItems[index].style != "radio" {
                dropdownCount+=1
            }
            for subIndex in 0..<userInputState.dropdownItems[index].values.count {
                let selectValue = userInputState.dropdownItems[index].values[subIndex]
                if selectValue.hasPrefix("---") && !selectValue.hasSuffix("<") {
                    // We need to modify each `---` entry so it is unique and doesn't cause errors when building the menu
                    userInputState.dropdownItems[index].values[subIndex].append(String(repeating: "-", count: subIndex).appending("<"))
                }
            }
        }
        _selectedOption = State(initialValue: defaultOptions)

        if dropdownCount > 0 {
            writeLog("Displaying select list")
        }
    }

    var body: some View {
        if observedData.args.dropdownValues.present && dropdownCount > 0 {
            VStack {
                ForEach(0..<userInputState.dropdownItems.count, id: \.self) {index in
                    if userInputState.dropdownItems[index].style != "radio" {
                        HStack {
                            // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                            // so we print it seperatly and use a blank value in the picker
                            HStack {
                                Text(userInputState.dropdownItems[index].title + (userInputState.dropdownItems[index].required ? " *":""))
                                    .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                                Spacer()
                            }
                            if userInputState.dropdownItems[index].style == "searchable" {
                                SearchablePicker(title: "", allItems: userInputState.dropdownItems[index].values, selection: $selectedOption[index])
                                    .onChange(of: selectedOption[index]) { _, selectedOption in
                                        userInputState.dropdownItems[index].selectedValue = selectedOption
                                    }
                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(userInputState.dropdownItems[index].requiredfieldHighlight, lineWidth: 2)
                                        .animation(
                                            .easeIn(duration: 0.2).repeatCount(3, autoreverses: true),
                                            value: observedData.showSheet
                                        )
                                    )
                            } else {
                                Picker("", selection: $selectedOption[index]) {
                                    if userInputState.dropdownItems[index].defaultValue.isEmpty {
                                        // prevents "Picker: the selection "" is invalid and does not have an associated tag" errors on stdout
                                        // this does mean we are creating a blank selection but it will still be index -1
                                        // previous indexing schemes (first entry being index 0 etc) should still apply.
                                        Text("").tag("")
                                    }
                                    ForEach(userInputState.dropdownItems[index].values, id: \.self) {
                                        if $0.hasPrefix("---") {
                                            Divider()
                                        } else {
                                            Text($0).tag($0)
                                                .font(.system(size: observedData.appProperties.labelFontSize))
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: selectedOption[index]) { _, selectedOption in
                                    userInputState.dropdownItems[index].selectedValue = selectedOption
                                }
                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                .buttonSizeFit()
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(userInputState.dropdownItems[index].requiredfieldHighlight, lineWidth: 2)
                                    .animation(
                                        .easeIn(duration: 0.2).repeatCount(3, autoreverses: true),
                                        value: observedData.showSheet
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .padding(10)
            .background(Color.background.opacity(0.5))
            .cornerRadius(8)

        }
    }
}

extension View {
    func buttonSizeFit() -> some View {
        if #available(macOS 26, *) {
            return buttonSizing(.flexible)
        } else {
            return self
        }
    }
}

// Implemtation of a searchable picker using TextField and popover with embedded scrollview

struct SearchablePicker: View {
    let title: String
    let allItems: [String]
    @Binding var selection: String

    @State private var searchText = ""
    @State private var showPopup = false
    @State private var userInteracted = false
    @FocusState private var isFocused: Bool
    @State private var selectedIndex: Int?
    @State private var didAppear = false
    
    static var lastHandledKeyCodes: Set<Int> = []

    var filteredItems: [String] {
        if searchText.isEmpty {
            allItems
        } else {
            allItems.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            TextField(title, text: $searchText, onEditingChanged: { isEditing in
                if isEditing && userInteracted {
                    showPopup.toggle()
                    selectedIndex = filteredItems.isEmpty ? nil : 0
                } else {
                    showPopup = false
                }
            })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .onChange(of: searchText) {
                    userInteracted = true
                    showPopup = true
                    selectedIndex = filteredItems.isEmpty ? nil : 0
                }
                .onAppear {
                    searchText = selection
                    showPopup = false
                    userInteracted = false
                    didAppear = true
                }
                .background(KeyHandlerView { event in
                    handleKey(event)
                })
                .popover(isPresented: $showPopup, arrowEdge: .bottom) {
                    VStack(spacing: 0) {
                        if filteredItems.isEmpty {
                            Text("No matches")
                                .padding()
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(filteredItems.indices, id: \.self) { index in
                                            let item = filteredItems[index]
                                            Text(item)
                                                .id(index)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(selectedIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                                                .onTapGesture {
                                                    select(item)
                                                }
                                        }
                                    }
                                }
                                .onChange(of: selectedIndex) { _, newIndex in
                                    if let newIndex {
                                        withAnimation {
                                            proxy.scrollTo(newIndex, anchor: .center)
                                        }
                                    }
                                }
                                .frame(width: 200)
                                .frame(minHeight: 100)
                                .frame(maxHeight: 350)
                            }
                        }
                    }
                    .padding()
                }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.primary, .clear)
                    .opacity(searchText.isEmpty ? 0.5 : 0)
                    .padding(.leading, 3)
                Spacer()
                Image(systemName: "chevron.up.chevron.down.square.fill")
                    .foregroundStyle(.primary, .clear)
                    .padding(.trailing, 3)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                userInteracted = true
                showPopup.toggle()
                selectedIndex = 0
            }
        }
    }

    private func handleKey(_ event: NSEvent) {
        // clear previously handled keys for this event
        SearchablePicker.lastHandledKeyCodes.removeAll()
        guard isFocused else { return }

        switch event.keyCode {
        case 125: // ↓
            userInteracted = true
            if !showPopup {
                showPopup = true
                selectedIndex = 0
            } else {
                moveSelection(1)
            }
            SearchablePicker.lastHandledKeyCodes.insert(Int(event.keyCode))
        case 126: // ↑
            moveSelection(-1)
            SearchablePicker.lastHandledKeyCodes.insert(Int(event.keyCode))
        case 36: // Return
            if showPopup, let index = selectedIndex, index < filteredItems.count {
                select(filteredItems[index])
            } else {
                return // don’t swallow Return — let it pass through
            }
            SearchablePicker.lastHandledKeyCodes.insert(Int(event.keyCode))
        case 53: // Escape
            showPopup = false
            SearchablePicker.lastHandledKeyCodes.insert(Int(event.keyCode))
        default:
            break
        }
    }

    private func moveSelection(_ delta: Int) {
        guard showPopup, !filteredItems.isEmpty else { return }
        if selectedIndex == nil {
            selectedIndex = 0
        } else {
            selectedIndex = max(0, min(filteredItems.count - 1, (selectedIndex ?? 0) + delta))
        }
    }

    private func select(_ item: String) {
        selection = item
        searchText = item
        // Keep the popover open briefly so the selection highlights
        withAnimation {
            selectedIndex = filteredItems.firstIndex(of: item)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showPopup = false
            isFocused = false
        }
    }

}

// MARK: - Key Handler View

struct KeyHandlerView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void
    static var currentHandler: ((NSEvent) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Install a single global monitor only once
        if context.coordinator.monitor == nil {
            context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                //KeyHandlerView.currentHandler?(event)
                // Only swallow keys if the handler actually used them
                if let handler = KeyHandlerView.currentHandler {
                    handler(event)
                    // Ask handler if it "handled" Return (⏎)
                    if SearchablePicker.lastHandledKeyCodes.contains(Int(event.keyCode)) {
                        return nil
                    }
                }
                return event
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // When this picker has focus, set it as the active handler
        KeyHandlerView.currentHandler = onKeyDown
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var monitor: Any?
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}




/*
 HStack {
     Spacer()
     Image(systemName: "chevron.up.chevron.down.square.fill")
         .foregroundColor(.accentColor).opacity(0.5)
         .onTapGesture {
             searchText = ""
             showPopup = false
         }
 }
 */
