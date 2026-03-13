import SwiftUI

enum MeetingProvider {
    case zoom, googleMeet, teams, webex, generic

    static func detect(from url: URL) -> MeetingProvider {
        let s = url.absoluteString.lowercased()
        if s.contains("zoom.us")                                    { return .zoom }
        if s.contains("meet.google") || s.contains("tel.meet")       { return .googleMeet }
        if s.contains("teams.microsoft") || s.contains("teams.live") { return .teams }
        if s.contains("webex.com")                                  { return .webex }
        return .generic
    }

    var label: String {
        switch self {
        case .zoom:        return "Zoom"
        case .googleMeet:  return "Meet"
        case .teams:       return "Teams"
        case .webex:       return "WebEx"
        case .generic:     return "Join"
        }
    }

    var joinLabel: String {
        switch self {
        case .zoom:        return "Join on Zoom"
        case .googleMeet:  return "Join on Meet"
        case .teams:       return "Join on Teams"
        case .webex:       return "Join on WebEx"
        case .generic:     return "Join Meeting"
        }
    }

    var color: Color {
        switch self {
        case .zoom:        return Color(red: 0.16, green: 0.44, blue: 0.87)
        case .googleMeet:  return Color(red: 0.06, green: 0.73, blue: 0.36)
        case .teams:       return Color(red: 0.37, green: 0.19, blue: 0.62)
        case .webex:       return Color(red: 0.0,  green: 0.47, blue: 0.84)
        case .generic:     return .accentColor
        }
    }
}
