//
//  SemanticColors.swift
//  Dialog
//
//  Semantic status colours for the inspect framework, matching the system colours.
//

import SwiftUI

/// Semantic colors for status indicators and UI elements.
extension Color {

    // MARK: - Status Colors

    /// Success/complete state - Apple system green (#34C759)
    static let semanticSuccess = Color(hex: "#34C759")

    /// Error/failure state - Apple system red (#FF3B30)
    static let semanticFailure = Color(hex: "#FF3B30")

    /// Warning/caution state - Apple system orange (#FF9F0A)
    static let semanticWarning = Color(hex: "#FF9F0A")

    /// Info/active state - Apple system blue (#007AFF)
    static let semanticInfo = Color(hex: "#007AFF")

    /// Pending/inactive state - System gray
    static let semanticPending = Color.secondary

    // MARK: - Convenience Aliases

    /// Alias for semanticSuccess - used for checkmarks, completed items
    static let statusComplete = semanticSuccess

    /// Alias for semanticFailure - used for X marks, failed items
    static let statusError = semanticFailure

    /// Alias for semanticWarning - used for in-progress, attention items
    static let statusActive = semanticWarning

    /// Alias for semanticInfo - used for highlights, selections
    static let statusNormal = semanticInfo

    // MARK: - Background Variants

    /// Light success background for cards/badges. 8% keeps text contrast without a second foreground colour.
    static let successBackground = semanticSuccess.opacity(0.08)

    /// Light failure background for cards/badges
    static let failureBackground = semanticFailure.opacity(0.08)

    /// Light warning background for cards/badges
    static let warningBackground = semanticWarning.opacity(0.08)

    /// Light info background for cards/badges
    static let infoBackground = semanticInfo.opacity(0.08)
}

// MARK: - Status Enum Support

extension Color {
    /// Get semantic color for a boolean match result
    static func forMatch(_ isMatch: Bool) -> Color {
        isMatch ? .semanticSuccess : .semanticFailure
    }
}

// MARK: - StatusGlyph → palette

/// Inspect's palette-aware reading of a `StatusGlyph`. Additive: `StatusGlyph.color` is shared
/// with classic Dialog and stays unchanged. `.error` and `.pending` fall through to the system
/// map because no inspect site constructs them.
extension StatusGlyph {
    func paletteColor(_ palette: ResolvedPalette) -> Color {
        switch self {
        case .success: palette.success
        case .failure: palette.error
        case .warning: palette.warning
        case .error, .pending: color
        }
    }

    /// The active/running tint: the accent, so a spinner matches the chip wash and status word.
    static func paletteActiveColor(_ palette: ResolvedPalette) -> Color {
        palette.accent
    }
}
