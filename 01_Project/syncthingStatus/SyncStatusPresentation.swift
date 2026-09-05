import SwiftUI

extension SyncStatusPolicy.FolderState {
    var symbolName: String {
        switch self {
        case .upToDate: return "checkmark.circle.fill"
        case .pending, .error: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        case .unavailable: return "questionmark.circle"
        case .active(let state): return state.hasPrefix("scan") ? "magnifyingglass" : "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .upToDate: return .green
        case .pending, .unavailable: return .orange
        case .error: return .red
        case .paused: return .secondary
        case .active: return .blue
        }
    }
}
