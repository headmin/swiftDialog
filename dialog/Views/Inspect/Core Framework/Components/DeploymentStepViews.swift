// DeploymentStepViews.swift
//
// The deployment step's rotating side message and its status sort order; used by Preset 5's
// deployment step and card carousel.

import SwiftUI

// MARK: - Side Message View

/// Rotating messages; the timer starts and stops with the view lifecycle.
struct DeploymentSideMessageView: View {
    let messages: [String]
    let interval: Int

    @State private var currentIndex: Int = 0
    @State private var rotation: Poll?

    var body: some View {
        if !messages.isEmpty {
            let safeIndex = min(currentIndex, messages.count - 1)
            Text(messages[safeIndex])
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 40, alignment: .leading)
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
                .onAppear {
                    startRotation()
                }
                .onDisappear {
                    rotation?.cancel()
                    rotation = nil
                }
        }
    }

    /// Cancels any running poll first so a return to the step never stacks a second ticker.
    private func startRotation() {
        guard messages.count > 1, interval > 0 else { return }
        rotation?.cancel()
        let poll = Poll(every: TimeInterval(interval))
        rotation = poll
        poll.start { currentIndex = (currentIndex + 1) % messages.count }
    }
}

// MARK: - Helpers

/// Sorts items completed → active → pending → failed → skipped; the list has no section headers,
/// so this order is the grouping.
func deploymentSortedItems(_ items: [InstallationItemData]) -> [InstallationItemData] {
    items.sorted { a, b in
        statusSortOrder(a.status) < statusSortOrder(b.status)
    }
}

private func statusSortOrder(_ status: StepStatus) -> Int {
    switch status {
    case .completed: return 0
    case .active: return 1
    case .pending: return 2
    case .failed: return 3
    case .skipped: return 4
    }
}
