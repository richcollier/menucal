import SwiftUI
import Foundation

struct LinkedResource: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let icon: String   // SF Symbol name
    let color: Color

    // Domains that appear in Google Calendar event descriptions but are not useful links
    private static let blockedHosts: Set<String> = [
        "support.google.com", "accounts.google.com", "calendar.google.com",
        "policies.google.com", "www.google.com",
    ]

    /// Extract and categorize links from event notes, excluding the meeting URL.
    static func extract(from notes: String?, excluding meetingURL: URL?) -> [LinkedResource] {
        var seen = Set<String>()
        var results: [LinkedResource] = []

        // Scan notes text with NSDataDetector
        guard let notes, !notes.isEmpty else { return results }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return results }
        let range = NSRange(notes.startIndex..., in: notes)
        let matches = detector.matches(in: notes, options: [], range: range)

        for match in matches {
            guard var url = match.url else { continue }
            guard url.scheme == "https" || url.scheme == "http" else { continue }

            // Unwrap Google redirect URLs (google.com/url?q=https://...)
            if let host = url.host, host.contains("google.com"),
               url.path == "/url",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let qParam = components.queryItems?.first(where: { $0.name == "q" })?.value,
               let unwrapped = URL(string: qParam) {
                url = unwrapped
            }

            let abs = url.absoluteString
            let host = url.host?.lowercased() ?? ""

            if blockedHosts.contains(host) { continue }
            if let meeting = meetingURL, abs == meeting.absoluteString { continue }

            let lower = abs.lowercased()
            let isMeeting = lower.contains("zoom.us/j/") || lower.contains("meet.google.com/")
                         || lower.contains("tel.meet/") || lower.contains("teams.microsoft.com/l/meetup")
                         || lower.contains("webex.com/meet") || lower.contains("webex.com/join")
                         || (lower.contains("webex.com") && (lower.contains("j.php") || lower.contains("/wc/")))
            if isMeeting { continue }

            guard seen.insert(abs).inserted else { continue }
            results.append(classify(url))
        }

        return results
    }

    static func classify(_ url: URL) -> LinkedResource {
        let s = url.absoluteString.lowercased()
        let host = url.host?.lowercased() ?? ""

        // Google Docs
        if host.contains("docs.google.com") {
            if s.contains("/spreadsheets") {
                return LinkedResource(url: url, title: "Google Sheets",  icon: "tablecells.fill",             color: Color(red: 0.13, green: 0.65, blue: 0.30))
            }
            if s.contains("/presentation") {
                return LinkedResource(url: url, title: "Google Slides",  icon: "play.rectangle.fill",         color: Color(red: 0.98, green: 0.64, blue: 0.0))
            }
            if s.contains("/forms") {
                return LinkedResource(url: url, title: "Google Forms",   icon: "list.bullet.rectangle.fill",  color: Color(red: 0.55, green: 0.27, blue: 0.75))
            }
            return         LinkedResource(url: url, title: "Google Docs",   icon: "doc.text.fill",               color: Color(red: 0.26, green: 0.52, blue: 0.96))
        }
        if host.contains("drive.google.com") {
            return             LinkedResource(url: url, title: "Google Drive",  icon: "folder.fill",                 color: Color(red: 0.26, green: 0.52, blue: 0.96))
        }
        // Notion
        if host.contains("notion.so") || host.contains("notion.site") {
            return LinkedResource(url: url, title: "Notion",            icon: "note.text",                   color: Color(NSColor.labelColor))
        }
        // GitHub
        if host.contains("github.com") {
            return LinkedResource(url: url, title: "GitHub",            icon: "chevron.left.forwardslash.chevron.right", color: Color(NSColor.labelColor))
        }
        // Figma
        if host.contains("figma.com") {
            return LinkedResource(url: url, title: "Figma",             icon: "paintbrush.pointed.fill",     color: Color(red: 0.71, green: 0.35, blue: 1.0))
        }
        // Confluence / Jira (Atlassian)
        if host.contains("atlassian.net") || host.contains("confluence") {
            if s.contains("/browse/") || s.contains("/jira/") {
                return LinkedResource(url: url, title: "Jira",          icon: "list.bullet.clipboard.fill",  color: Color(red: 0.0, green: 0.45, blue: 0.93))
            }
            return         LinkedResource(url: url, title: "Confluence", icon: "doc.richtext.fill",            color: Color(red: 0.0, green: 0.45, blue: 0.93))
        }
        // Dropbox
        if host.contains("dropbox.com") {
            return LinkedResource(url: url, title: "Dropbox",           icon: "archivebox.fill",             color: Color(red: 0.0, green: 0.45, blue: 0.93))
        }
        // SharePoint / OneDrive
        if host.contains("sharepoint.com") || host.contains("onedrive.live.com") {
            return LinkedResource(url: url, title: "SharePoint",        icon: "folder.fill",                 color: Color(red: 0.13, green: 0.49, blue: 0.97))
        }
        // Loom
        if host.contains("loom.com") {
            return LinkedResource(url: url, title: "Loom",              icon: "video.fill",                  color: Color(red: 0.62, green: 0.27, blue: 0.98))
        }
        // Miro
        if host.contains("miro.com") {
            return LinkedResource(url: url, title: "Miro",              icon: "rectangle.on.rectangle",      color: Color(red: 1.0,  green: 0.72, blue: 0.0))
        }
        // Generic
        let displayHost = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        return LinkedResource(url: url, title: displayHost,             icon: "link",                        color: .secondary)
    }
}
