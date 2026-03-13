import SwiftUI

struct EventRowView: View {
    let event: CalendarEvent
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if isExpanded {
                EventDetailView(event: event)
                    .padding(.leading, 40)
                    .padding(.trailing, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(event.isPast ? 0.45 : 1.0)
    }

    // MARK: - Main row

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 10) {
            // Calendar color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3, height: 34)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if event.isInProgress {
                inProgressBadge
            }

            if let url = event.meetingURL {
                JoinButton(url: url, isImminent: event.minutesUntilStart <= 5 && !event.isPast)
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
    }

    private var inProgressBadge: some View {
        Text("Now")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.accentColor)
            .clipShape(Capsule())
    }

    private var rowBackground: some View {
        event.isInProgress
            ? Color.accentColor.opacity(0.08)
            : Color.clear
    }

    private var timeRangeString: String {
        if event.isAllDay { return "All day" }
        let start = DateFormatters.time.string(from: event.startDate)
        let end   = DateFormatters.time.string(from: event.endDate)
        return "\(start) – \(end)"
    }
}

// MARK: - Join Button

struct JoinButton: View {
    let url: URL
    let isImminent: Bool

    private var provider: MeetingProvider { MeetingProvider.detect(from: url) }

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Text(provider.label)
                .font(.caption.bold())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(isImminent ? .green : provider.color)
    }
}
