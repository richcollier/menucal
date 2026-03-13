import Foundation
import Combine

// MARK: - Token types

enum MenuBarToken: String, CaseIterable, Codable {
    case eventTitle   = "event-title"
    case countdown    = "countdown"
    case clock        = "clock"
    case date         = "date"
    case dayProgress  = "day-progress"
    case yearProgress = "year-progress"

    var displayName: String {
        switch self {
        case .eventTitle:   return "Next Event Title"
        case .countdown:    return "Countdown"
        case .clock:        return "Clock"
        case .date:         return "Date"
        case .dayProgress:  return "Day Progress"
        case .yearProgress: return "Year Progress"
        }
    }

    var example: String {
        switch self {
        case .eventTitle:   return "Team Standup"
        case .countdown:    return "in 12m"
        case .clock:        return "2:34 PM"
        case .date:         return "Thu Mar 12"
        case .dayProgress:  return "▓▓▓░░░░░"
        case .yearProgress: return "19%"
        }
    }

    var icon: String {
        switch self {
        case .eventTitle:   return "text.alignleft"
        case .countdown:    return "timer"
        case .clock:        return "clock"
        case .date:         return "calendar"
        case .dayProgress:  return "chart.bar.fill"
        case .yearProgress: return "percent"
        }
    }
}

// MARK: - Per-token config (ordered list with enabled flag)

struct TokenConfig: Identifiable, Codable, Equatable {
    let token: MenuBarToken
    var enabled: Bool
    var id: String { token.rawValue }

    static let defaults: [TokenConfig] = [
        TokenConfig(token: .eventTitle,   enabled: true),
        TokenConfig(token: .countdown,    enabled: true),
        TokenConfig(token: .date,         enabled: false),
        TokenConfig(token: .clock,        enabled: false),
        TokenConfig(token: .dayProgress,  enabled: false),
        TokenConfig(token: .yearProgress, enabled: false),
    ]
}

// MARK: - Settings manager (singleton, owned by MenuBarManager)

class TokenSettingsManager: ObservableObject {
    static let shared = TokenSettingsManager()

    private let key = "menubar.tokens"

    @Published var configs: [TokenConfig] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "menubar.tokens"),
           let decoded = try? JSONDecoder().decode([TokenConfig].self, from: data) {
            // Merge: add any newly introduced tokens not present in saved data
            var merged = decoded
            for token in MenuBarToken.allCases where !merged.contains(where: { $0.token == token }) {
                merged.append(TokenConfig(token: token, enabled: false))
            }
            configs = merged
        } else {
            configs = TokenConfig.defaults
        }
    }

    var enabledTokens: [MenuBarToken] {
        configs.filter { $0.enabled }.map { $0.token }
    }

    var previewString: String {
        let parts = enabledTokens.map { $0.example }
        return parts.isEmpty ? "📅" : parts.joined(separator: "  ")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
