//
//  ButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

struct ButtonBarView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var progressSteps: CGFloat = appDefaults.timerDefaultSeconds

    var buttonCentreStyle: Bool = false
    var buttonStackStyle: Bool = false

    var defaultExit: Int32 = 0
    var cancelExit: Int32 = 2
    var infoExit: Int32 = 3

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        buttonCentreStyle = ["centre","center","centred","centered"].contains(observedDialogContent.args.buttonStyle.value)
        buttonStackStyle = ["stack"].contains(observedDialogContent.args.buttonStyle.value)

        if observedDialogContent.args.timerBar.present {
            progressSteps = observedDialogContent.args.timerBar.value.floatValue()
        }
        
    }

    var body: some View {
        
        let buttonLayout = (buttonStackStyle ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout()))
        
        buttonLayout {
            if !buttonStackStyle && !buttonCentreStyle {
                // only show this content if not in stack or centre mode
                HStack {
                    // info button or text
                    if observedData.args.infoText.present {
                        Text(observedData.args.infoText.value)
                            .foregroundColor(.secondary.opacity(0.7))
                    } else if (observedData.args.infoButtonOption.present ||
                               observedData.args.buttonInfoTextOption.present) &&
                                !observedData.args.miniMode.present {

                        NewButton(label: observedData.args.buttonInfoTextOption.value == "nil" ? "" : observedData.args.buttonInfoTextOption.value,
                                    symbolName: observedData.args.buttonInfoSymbol.value,
                                    symbolIsVisible: observedData.args.buttonInfoSymbol.present,
                                    buttonFontSize: observedData.appProperties.buttonTextSize,
                                    buttonStyle: observedData.appProperties.buttonSize,
                                    action: observedData.args.buttonInfoActionOption.value,
                                    shouldQuit: observedData.args.quitOnInfo.present,
                                    exitCode: 3,
                                    observedData: observedData
                        )
                    }
                    if observedData.args.timerBar.present {
                        TimerView(progressSteps: progressSteps, visible: !observedData.args.hideTimerBar.present, observedDialogContent: observedData)
                            .frame(alignment: .bottom)
                    }
                }
            }
            
            Spacer()
            
            // Additional Buttons can go here if we implement it
            
            
            // Default Cancel button
            if observedData.args.button2TextOption.present || observedData.args.button2Option.present {
                NewButton(label: observedData.args.button2TextOption.value == "nil" ? "" : observedData.args.button2TextOption.value,
                          isDisabled: observedData.args.button2Disabled.present,
                          enableOnChangeOf: $observedData.args.button2Disabled.present,
                          isStacked: buttonStackStyle,
                          symbolName: observedData.args.button2Symbol.value,
                          symbolIsVisible: observedData.args.button2Symbol.present,
                          keyboardShortcut: .cancelAction,
                          buttonFontSize: observedData.appProperties.buttonTextSize,
                          buttonStyle: observedData.appProperties.buttonSize,
                          shouldQuit: true,
                          exitCode: 2,
                          observedData: observedData
                )
            }
            
            // Default Primary button
            if observedData.args.button1TextOption.value != "none" {
                NewButton(label: observedData.args.button1TextOption.value == "nil" ? "" : observedData.args.button1TextOption.value,
                          isDisabled: observedData.args.button1Disabled.present,
                          enableOnTimer: (observedData.args.timerBar.present && !observedData.args.hideTimerBar.present),
                          enableOnChangeOf: $observedData.args.button1Disabled.present,
                          isStacked: buttonStackStyle,
                          symbolName: observedData.args.button1Symbol.value,
                          symbolIsVisible: observedData.args.button1Symbol.present,
                          keyboardShortcut: .defaultAction,
                          buttonFontSize: observedData.appProperties.buttonTextSize,
                          buttonStyle: observedData.appProperties.buttonSize,
                          shouldQuit: true,
                          exitCode: 0,
                          observedData: observedData
                )
            }
            
            // Help Button
            if !buttonStackStyle && !buttonCentreStyle {
                HelpButton(observedDialogContent: observedData)
            }
            
            if buttonCentreStyle {
                Spacer()
            }
            
        }
        
    }
}

struct HelpButton: View {
    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        if observedData.args.helpMessage.present {
            Button(action: {
                observedData.appProperties.showHelpMessage.toggle()
            }, label: {
                ZStack {
                    Circle()
                        .foregroundColor(.white)
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.secondaryBackground)
                    Text("?")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 22, height: 22)
            })
            .focusable(false)
            .buttonStyle(HelpButtonStyle())
            .sheet(isPresented: $observedData.appProperties.showHelpMessage) {
                HelpView(observedContent: observedData)
                    .background(WindowAccessor { window in
                        window?.canBecomeVisibleWithoutLogin = true
                    })
            }
        }
    }

}

struct HelpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .help(String("Click for additional information".localized))
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct NewButton: View {
    
    var label: String
    @State var isDisabled: Bool = false
    var enableOnTimer: Bool = false
    var enableOnChangeOf: Binding<Bool>?
    var isStacked: Bool = false
    @State var symbolName: String = ""
    @State var symbolPosition: IconPosition = .leading
    var symbolIsVisible: Bool = false
    @State var symbolRenderingMode: SymbolRenderingMode = .monochrome
    @State var symbolColour: Color = .primary
    @State var symbolSize: CGFloat = 16
    var keyboardShortcut: KeyboardShortcut = .init(.return)
    var buttonMinWidth: CGFloat = 40
    @State var buttonFontSize: CGFloat?
    var buttonStyle: ControlSize = .regular
    var action: String = ""
    var isShellCommand: Bool = false
    var shouldQuit: Bool = false
    var exitCode: Int32 = 0
    @ObservedObject var observedData: DialogUpdatableContent
    
    @State private var symbolColour2: Color = .clear
    @State private var symbolColour3: Color = .clear
    
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    @FocusState private var isFocused: Bool
    @State private var needsFocusRefresh = false
    
    private func symbolProcessing() {
        // Populate symbol properties from name
        let symbolParts = symbolName.split(separator: ",").map { $0.lowercased() }
        guard let firstName = symbolParts.first else { return }
        symbolName = firstName

        // Check last two parts for position and rendering mode
        for part in symbolParts.dropFirst() {
            if let position = part.toSymbolPosition {
                self.symbolPosition = position
            }
            if let renderingMode = part.toSymbolRenderingMode {
                self.symbolRenderingMode = renderingMode
            }
            if part.starts(with: "size=") {
                self.symbolSize = Double(part.split(separator: "=").last ?? "16") ?? 16
            }
            if part.prefixMatch(of: /colou?r=/) != nil {
                self.symbolColour = Color(argument: part.split(separator: "=").last?.lowercased() ?? "primary")
            }
            if part.starts(with: "palette=") {
                self.symbolRenderingMode = .palette
                let paletteColours = part.split(separator: "=").last!.split(separator: "-").map { $0.lowercased() }
                switch paletteColours.count {
                    case 1: self.symbolColour = Color(argument: paletteColours[0])
                    case 2: self.symbolColour = Color(argument: paletteColours[0]); self.symbolColour2 = Color(argument: paletteColours[1])
                    case 3: self.symbolColour = Color(argument: paletteColours[0]); self.symbolColour2 = Color(argument: paletteColours[1]); self.symbolColour3 = Color(argument: paletteColours[2])
                    default: break
                }
            }
        }
        needsFocusRefresh = true
    }
    
    var body: some View {
        // .top and .bottom force VStack, otherwise HStack
        let symbolLayout = (symbolPosition == .top || symbolPosition == .bottom) ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
        
        Button(action: {
            buttonAction(action: action, exitCode: exitCode, executeShell: isShellCommand, shouldQuit: shouldQuit, observedObject: observedData)
        }, label: {
            symbolLayout {
                if !label.isEmpty && (symbolPosition == .bottom) {
                    Text(label)
                        .font(buttonFontSize != nil ? .system(size: buttonFontSize!) : .body)
                }
                if symbolIsVisible {
                    Image(systemName: symbolName)
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(symbolRenderingMode)
                        .frame(height: symbolSize)
                        .foregroundStyle(symbolColour, symbolColour2, symbolColour3)
                        .padding(2)
                }
                if !label.isEmpty && (symbolPosition != .bottom) {
                    Text(label)
                        .font(buttonFontSize != nil ? .system(size: buttonFontSize!) : .body)
                }
            }
            .frame(minWidth: buttonMinWidth, alignment: .center)
            .frame(maxWidth: isStacked ? .infinity: nil)
            .environment(\.layoutDirection, (symbolPosition == .leading) ? .leftToRight : .rightToLeft)
        })
        .focused($isFocused)
        .keyboardShortcut(keyboardShortcut)
        .controlSize(buttonStyle)
        .disabled(isDisabled)
        .onReceive(timer) { _ in
            if enableOnTimer && isDisabled {
                isDisabled = false
            }
        }
        .onChange(of: enableOnChangeOf?.wrappedValue ?? false) { _, value in
            isDisabled = value
        }
        .onChange(of: observedData.args.buttonTextSize.value) { _, value in
            buttonFontSize = String(value).floatValue()
        }
        .onAppear {
            symbolProcessing()
        }
        .onChange(of: needsFocusRefresh) { _, refresh in
            if refresh {
                isFocused = false
                DispatchQueue.main.async {
                    isFocused = true
                    needsFocusRefresh = false
                }
            }
        }
    }
}
