import Foundation

enum MeetingURLDetector {

    /// Scans notes and location strings for a video conference URL.
    static func extractURL(fromNotes notes: String?, location: String?) -> URL? {
        let texts = [notes, location].compactMap { $0 }
        for text in texts {
            if let url = firstMeetingURL(in: text) { return url }
        }
        return nil
    }

    private static let patterns: [String] = [
        #"https://[^\s"<>]*meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}[^\s"<>]*"#,
        #"https://tel\.meet/[a-z]{3}-[a-z]{4}-[a-z]{3}[^\s"<>]*"#,
        #"https://[^\s"<>]*zoom\.us/j/[0-9]+[^\s"<>]*"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+"#,
        #"https://[^\s"<>]*webex\.com/meet/[^\s"<>]+"#,
        #"https://[^\s"<>]*webex\.com/join/[^\s"<>]+"#,
        #"https://[^\s"<>]*webex\.com/[^\s"<>]*j\.php[^\s"<>]*"#,
        #"https://[^\s"<>]*webex\.com/wc/[^\s"<>]+"#,
    ]

    private static func firstMeetingURL(in text: String) -> URL? {
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: match) { return url }
            }
        }
        return nil
    }
}
