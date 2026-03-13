import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject var calendarService: EventKitService

    var body: some View {
        Group {
            if calendarService.accessGranted {
                VStack(spacing: 0) {
                    EventListView()
                    Divider()
                    MiniCalendarView()
                }
            } else {
                CalendarAccessView()
            }
        }
        .frame(width: 340, height: 560)
    }
}

// MARK: - Shown when calendar access hasn't been granted yet

struct CalendarAccessView: View {
    @EnvironmentObject var calendarService: EventKitService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("Calendar Access Needed")
                    .font(.title3.bold())
                Text("MenuCal needs access to your calendars to show upcoming events.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let error = calendarService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Grant Access") {
                Task { await calendarService.requestAccessAndFetch() }
            }
            .buttonStyle(.borderedProminent)

            Button("Open Privacy Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                )
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}
