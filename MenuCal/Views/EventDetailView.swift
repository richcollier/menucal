import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent

    // Strip Google Calendar conference block (content between -::~:: separator lines)
    private var userNotes: String? {
        guard let notes = event.notes else { return nil }
        let lines = notes.components(separatedBy: "\n")

        func isSeparator(_ line: String) -> Bool {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.count > 8, t.hasPrefix("-") else { return false }
            return t.allSatisfy { "-:~".contains($0) }
        }

        var result: [String] = []
        var inBlock = false
        for line in lines {
            if isSeparator(line) { inBlock.toggle(); continue }
            if !inBlock { result.append(line) }
        }

        let boilerplate = ["join with google meet", "please do not edit", "or dial:", "more phone numbers:", "learn more about meet"]
        let filtered = result.filter { line in
            let lower = line.lowercased()
            return !boilerplate.contains(where: { lower.hasPrefix($0) })
        }

        let text = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var links: [LinkedResource] {
        LinkedResource.extract(from: userNotes, excluding: event.meetingURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Join button
            if let url = event.meetingURL {
                let provider = MeetingProvider.detect(from: url)
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(provider.joinLabel, systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(provider.color)
                .padding(.top, 4)
                .padding(.trailing, 4)
            }

            // Links surfaced from notes text
            if !links.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(links) { link in
                        HStack(spacing: 6) {
                            Image(systemName: link.icon)
                                .font(.caption)
                                .foregroundColor(link.color)
                                .frame(width: 14)
                            Text(link.title)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { NSWorkspace.shared.open(link.url) }
                    }
                }
            }

            // Location
            if let location = event.location {
                DetailRow(icon: "mappin.circle", text: location) {
                    if let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://maps.apple.com/?q=\(query)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            // Attendees
            if !event.attendees.isEmpty {
                attendeesRow
            }

            // User-written notes (conference block stripped)
            if let notes = userNotes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.top, 2)
            }

            // Open in Google Calendar
            if let url = googleCalendarURL {
                HStack {
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Open in Google Calendar")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    private var googleCalendarURL: URL? {
        guard event.isGoogleCalendar else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: event.startDate)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return nil }
        return URL(string: "https://calendar.google.com/calendar/r/day/\(year)/\(month)/\(day)")
    }

    // MARK: - Attendees

    private var attendeesRow: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "person.2")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                let visible = event.attendees.prefix(4)
                let overflow = max(0, event.attendees.count - 4)

                ForEach(visible) { attendee in
                    HStack(spacing: 4) {
                        AvatarView(attendee: attendee)
                        Text(attendee.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        responseIcon(for: attendee.responseStatus)
                    }
                }

                if overflow > 0 {
                    Text("+\(overflow) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func responseIcon(for status: Attendee.ResponseStatus) -> some View {
        switch status {
        case .accepted:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption2)
        case .declined:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.caption2)
        case .tentative:
            Image(systemName: "questionmark.circle.fill").foregroundColor(.orange).font(.caption2)
        case .needsAction:
            EmptyView()
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let text: String
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundColor(action != nil ? .accentColor : .secondary)
                .lineLimit(2)
                .onTapGesture { action?() }
        }
    }
}

// MARK: - Avatar

private struct AvatarView: View {
    let attendee: Attendee

    var initials: String {
        let parts = (attendee.name ?? attendee.email).components(separatedBy: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        Text(initials.prefix(2))
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(Color.accentColor.opacity(0.7)))
    }
}
