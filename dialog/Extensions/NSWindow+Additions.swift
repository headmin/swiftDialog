//
//  WindowPositioning.swift
//  dialog
//
//  Created by Bart Reardon on 26/9/2022.
//
// logic updated from https://stackoverflow.com/questions/70091919/how-set-position-of-window-on-the-desktop-in-swiftui

import AppKit
import Combine
import SwiftUI

extension NSWindow {

    struct Position {

        static let defaultPadding: CGFloat = 16

        var vertical: Vertical
        var horizontal: Horizontal
        var padding = Self.defaultPadding
    }
}

extension NSWindow.Position {

    enum Horizontal {
        case left, center, right, explicit(CGFloat)
    }

    enum Vertical {
        case top, center, deadcenter, bottom, explicit(CGFloat)
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitorView(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
    }

    func makeCoordinator() -> WindowMonitor {
        WindowMonitor(onChange)
    }

    class WindowMonitor: NSObject {
        private var cancellables = Set<AnyCancellable>()
        private var onChange: (NSWindow?) -> Void

        init(_ onChange: @escaping (NSWindow?) -> Void) {
            self.onChange = onChange
        }

        /// This function uses KVO to observe the `window` property of `view` and calls `onChange()`
        func monitorView(_ view: NSView) {
            view.publisher(for: \.window)
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] newWindow in
                    guard let self = self else { return }
                    self.onChange(newWindow)
                    if let newWindow = newWindow {
                        self.monitorClosing(of: newWindow)
                    }
                }
                .store(in: &cancellables)
        }

        /// This function uses notifications to track closing of `window`
        private func monitorClosing(of window: NSWindow) {
            NotificationCenter.default
                .publisher(for: NSWindow.willCloseNotification, object: window)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.onChange(nil)
                    self.cancellables.removeAll()
                }
                .store(in: &cancellables)
        }
    }
}

func calculateWindowYPos(screenHeight: CGFloat, position: NSWindow.Position.Vertical, offset: CGFloat) -> CGFloat {
    let ypos: CGFloat
    switch position {
    case .top: ypos = offset
    case .center:
        ypos = (screenHeight / 2) - (screenHeight * 0.15)
    case .deadcenter: ypos = screenHeight / 2
    case .bottom: ypos = screenHeight - offset
    case .explicit(let value):
        ypos = value
    }
    return screenHeight - ypos
}

func calculateWindowXPos(screenWidth: CGFloat, position: NSWindow.Position.Horizontal, offset: CGFloat) -> CGFloat {
    switch position {
    case .left: return offset
    case .center: return screenWidth / 2
    case .right: return screenWidth - offset
    case .explicit(let value):
        return value
    }
}


func placeWindow(_ window: NSWindow, size: CGSize?, vertical: NSWindow.Position.Vertical, horozontal: NSWindow.Position.Horizontal, offset: CGFloat) {
    let main = NSScreen.main!
    let visibleFrame = main.visibleFrame
    let titleBarOffset: CGFloat = (main.frame.height - visibleFrame.height) + 1
    let visibleFrameOriginX = visibleFrame.origin.x
    let visibleFrameOriginY = visibleFrame.origin.y
    let visibleFrameWidth = visibleFrame.width
    let visibleFrameHeight = visibleFrame.height
    let screenOriginWidth = main.frame.width
    let screenOriginHeight = main.frame.height
    
    // Set window Size
    var windowSize: CGSize
    
    if size == nil {
        windowSize = window.frame.size
    } else {
        windowSize = CGSize(width: size?.width ?? window.frame.width, height: (size?.height ?? window.frame.height) + titleBarOffset)
    }
    writeLog("windowsize = \(String(describing: windowSize))", logLevel: .debug)
    writeLog("main frame = \(main.frame)", logLevel: .debug)
    writeLog("screenOriginX = \(main.frame.origin.x)", logLevel: .debug)
    writeLog("screenOriginY = \(main.frame.origin.y)", logLevel: .debug)
    writeLog("screenOriginWidth = \(screenOriginWidth)", logLevel: .debug)
    writeLog("screenOriginHeight = \(screenOriginHeight)", logLevel: .debug)
    writeLog("visible frame width = \(visibleFrameWidth)", logLevel: .debug)
    writeLog("visible frame height = \(visibleFrameHeight)", logLevel: .debug)
    writeLog("visible frame origin x = \(visibleFrameOriginX)", logLevel: .debug)
    writeLog("visible frame origin y = \(visibleFrameOriginY)", logLevel: .debug)
    writeLog("visible frame size = \(visibleFrame.size)", logLevel: .debug)
    

    // Set Window x and y Position based on size and offset
    let windowX = visibleFrameOriginX + calculateWindowXPos(screenWidth: visibleFrameWidth - windowSize.width, position: horozontal, offset: offset)
    let windowY = visibleFrameOriginY + calculateWindowYPos(screenHeight: visibleFrameHeight - windowSize.height, position: vertical, offset: offset)
    writeLog("window x = \(windowX)", logLevel: .debug)
    writeLog("window y = \(windowY)", logLevel: .debug)
    
    // If x or y positions are off the screen (when using explicit coordinates) re-adjust to fit in the visible frame
    let adjustedWindowX = max(windowX, min(windowX, visibleFrameOriginX + visibleFrameWidth - windowSize.width))
    let adjustedWindowY = max(windowY, min(windowY, visibleFrameOriginY + visibleFrameHeight - windowSize.height))

    writeLog("Adjusted window x = \(adjustedWindowX)", logLevel: .debug)
    writeLog("Adjusted window y = \(adjustedWindowY)", logLevel: .debug)
    
    // Set window frame
    let newFrame = NSRect(x: adjustedWindowX, y: adjustedWindowY, width: windowSize.width, height: windowSize.height)
    window.setFrame(newFrame, display: true)
    writeLog("Final window frame is \(window.frame)", logLevel: .debug)
}

func windowPosition(_ position: String) -> (vertical: NSWindow.Position.Vertical, horozontal: NSWindow.Position.Horizontal) {
    switch position {
    case "topleft":
        return (vertical: .top, horozontal: .left)
    case "topright":
        return (vertical: .top, horozontal: .right)
    case "bottomleft":
        return (vertical: .bottom, horozontal: .left)
    case "bottomright":
        return (vertical: .bottom, horozontal: .right)
    case "left":
        return (vertical: .center, horozontal: .left)
    case "right":
        return (vertical: .center, horozontal: .right)
    case "top":
        return (vertical: .top, horozontal: .center)
    case "bottom":
        return (vertical: .bottom, horozontal: .center)
    case "centre","center":
        return (vertical: .deadcenter, horozontal: .center)
    case "default":
        return (vertical: .center, horozontal: .center)
    default:
        return (vertical: .center, horozontal: .center)
    }
}
