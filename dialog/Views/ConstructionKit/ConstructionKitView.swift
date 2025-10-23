//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI
import SwiftyJSON

var jsonFormattedOutout: String = ""

struct LabelView: View {
    var label: String
    var body: some View {
        VStack {
            Divider()
            HStack {
                Text(label)
                    .fontWeight(.bold)
                Spacer()
            }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack {
            ZStack {
                IconView(image: "default")
                //Image(systemName: "bubble.left.circle.fill")
                //    .resizable()

                IconView(image: "sf=wrench.and.screwdriver.fill", alpha: 0.5, defaultColour: "white")
            }
            .frame(width: 150, height: 150)
            
            Text("ck-welcome".localized)
                .font(.largeTitle)
            Divider()
            Text("ck-welcomeinfo".localized)
                .foregroundColor(.secondary)
        }
    }
}

struct ConstructionKitView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        // mark all standard fields visible
        observedDialogContent.args.titleOption.present = true
        observedDialogContent.args.titleFont.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.iconOption.present = true
        observedDialogContent.args.iconSize.present = true
        observedDialogContent.args.button1TextOption.present = true
        observedDialogContent.args.windowWidth.present = true
        observedDialogContent.args.windowHeight.present = true
        observedDialogContent.args.movableWindow.present = true

    }

    public func showConstructionKit() {

        var window: NSWindow!
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
               styleMask: [.titled, .closable, .miniaturizable, .resizable],
               backing: .buffered, defer: false)
        window.title = "swiftDialog Construction Kit"
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedData))
        placeWindow(window, size: CGSize(width: 700,
                                         height: 900), vertical: .center, horozontal: .right, offset: 10)
    }

    var body: some View {

        NavigationView {
            List {
                Section(header: Text("ck-basic".localized)) {
                    NavigationLink(destination: CKTitleView(observedDialogContent: observedData)) {
                        Text("Title Bar".localized)
                    }
                    NavigationLink(destination: CKMessageView(observedDialogContent: observedData)) {
                        Text("Message".localized)
                    }
                    NavigationLink(destination: CKWindowProperties(observedDialogContent: observedData)) {
                        Text("ck-window".localized)
                    }
                    NavigationLink(destination: CKIconView(observedDialogContent: observedData)) {
                        Text("ck-icon".localized)
                    }
                    NavigationLink(destination: CKSidebarView(observedDialogContent: observedData)) {
                        Text("ck-sidebar".localized)
                    }
                    NavigationLink(destination: CKButtonView(observedDialogContent: observedData)) {
                        Text("ck-buttons".localized)
                    }
                }
                Section(header: Text("Data Entry")) {
                    NavigationLink(destination: CKTextEntryView(observedDialogContent: observedData)) {
                        Text("Text Fields".localized)
                    }
                    //NavigationLink(destination: CKSelectListsView(observedDialogContent: observedData)) {
                    //    Text("Select Lists".localized)
                    //}
                    NavigationLink(destination: CKCheckBoxesView(observedDialogContent: observedData)) {
                        Text("Checkboxes".localized)
                    }
                }
                Section(header: Text("ck-advanced".localized)) {
                    NavigationLink(destination: CKListView(observedDialogContent: observedData)) {
                        Text("ck-listitems".localized)
                    }
                    NavigationLink(destination: CKImageView(observedDialogContent: observedData)) {
                        Text("ck-images".localized)
                    }
                    NavigationLink(destination: CKMediaView(observedDialogContent: observedData)) {
                        Text("ck-media".localized)
                    }
                }
                Spacer()
                Section(header: Text("ck-output".localized)) {
                    NavigationLink(destination: JSONView(observedDialogContent: observedData) ) {
                        Text("ck-jsonoutput".localized)
                    }
                }
            }
            .padding(10)

            WelcomeView()
        }
        .listStyle(SidebarListStyle())
        //.frame(minWidth: 800, height: 800)
        Divider()
        ZStack {
            Spacer()
            HStack {
                Button("ck-quit".localized) {
                    quitDialog(exitCode: appDefaults.exit0.code)
                }
                Spacer()
                .disabled(false)
                Button("ck-exportcommand".localized) {}
                    .disabled(true)
            }
        }
        .padding(20)
    }
}
