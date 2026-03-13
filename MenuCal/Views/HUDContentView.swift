import SwiftUI
import Combine

struct HUDContentView: View {
    let event: CalendarEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    // Countdown to auto-dismiss (30 seconds)
    @State private var secondsLeft = 30

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            // Action row
            HStack(spacing: 8) {
                if event.meetingURL != nil {
                    Button("Join Meeting", action: onJoin)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                    Button("Snooze 5m", action: onSnooze)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                } else {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                }

                Spacer()

                Text("\(secondsLeft)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .frame(width: 340)
        .onReceive(timer) { _ in
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                onDismiss()
            }
        }
    }

    private var timeLabel: String {
        if event.isInProgress {
            let mins = max(0, Int(event.endDate.timeIntervalSinceNow / 60))
            return "In progress — ends in \(mins)m"
        }
        let mins = event.minutesUntilStart
        return mins == 0 ? "Starting now" : "Starts in \(mins)m"
    }
}
