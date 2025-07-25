//
//  InspectLayoutProtocol.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//

import SwiftUI

// MARK: - Protocol Definition

protocol InspectLayoutProtocol {
    associatedtype Body: View
    
    var inspectState: InspectState { get }
    var isMini: Bool { get }
    
    @ViewBuilder var body: Body { get }
}

// MARK: - Protocol Extension

extension InspectLayoutProtocol {
    
    // MARK: Properties
    
    var scaleFactor: CGFloat {
        return isMini ? 0.75 : 1.0
    }
    
    // MARK: Item Sorting
    
    func getSortedItemsByStatus() -> [InspectConfig.ItemConfig] {
        let completedItems = inspectState.items.filter { inspectState.completedItems.contains($0.id) }
        let downloadingItems = inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }
        let pendingItems = inspectState.items.filter { 
            !inspectState.completedItems.contains($0.id) && !inspectState.downloadingItems.contains($0.id) 
        }
        
        return completedItems + downloadingItems + pendingItems
    }
    
    func getItemStatusType(for item: InspectConfig.ItemConfig) -> ItemStatusType {
        if inspectState.completedItems.contains(item.id) {
            return .completed
        } else if inspectState.downloadingItems.contains(item.id) {
            return .downloading
        } else {
            return .pending
        }
    }
    
    func getItemStatus(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            return "Installed"
        } else if inspectState.downloadingItems.contains(item.id) {
            return "Installing..."
        } else {
            return "Waiting"
        }
    }
    
    // MARK: UI Components
    
    @ViewBuilder
    func buttonArea() -> some View {
        HStack(spacing: 12) {
            if inspectState.completedItems.count == inspectState.items.count && 
               inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(inspectState.buttonConfiguration.button2Text) {
                    writeLog("InspectView: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                    exit(2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(inspectState.buttonConfiguration.button2Disabled)
            }
            
            Button(inspectState.buttonConfiguration.button1Text) {
                writeLog("InspectView: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                exit(0)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(inspectState.buttonConfiguration.button1Disabled)
        }
    }
    
    @ViewBuilder
    func itemIcon(for item: InspectConfig.ItemConfig, size: CGFloat) -> some View {
        if let iconPath = item.icon,
           FileManager.default.fileExists(atPath: iconPath) {
            Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.75))
                .foregroundColor(.blue)
                .frame(width: size, height: size)
        }
    }
    
    @ViewBuilder
    func statusIndicator(for item: InspectConfig.ItemConfig) -> some View {
        if inspectState.completedItems.contains(item.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        } else if inspectState.downloadingItems.contains(item.id) {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
        }
    }
}

// MARK: - Supporting Types

enum ItemStatusType {
    case completed
    case downloading  
    case pending
}
