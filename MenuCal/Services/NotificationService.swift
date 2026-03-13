import UserNotifications
import AppKit
import Combine

@MainActor
class NotificationService {

    static let categoryID = "MEETING_REMINDER"

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup (call from applicationWillFinishLaunching)

    func registerCategories() {
        let join = UNNotificationAction(
            identifier: "JOIN",
            title: "Join",
            options: .foreground
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 5m",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [join, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async {
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("MenuCal: notification auth error: \(error)")
        }
    }

    // MARK: - Scheduling

    func scheduleReminders(for events: [CalendarEvent], minutesBefore: Int) async {
        center.removeAllPendingNotificationRequests()

        let now = Date()
        for event in events {
            guard !event.isPast, !event.isAllDay else { continue }
            let fireDate = event.startDate.addingTimeInterval(-Double(minutesBefore) * 60)
            guard fireDate > now else { continue }
            await schedule(event: event, at: fireDate, minutesBefore: minutesBefore)
        }
    }

    func scheduleSnooze(for event: CalendarEvent, minutes: Int = 5) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Snoozed — starting soon"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        if let url = event.meetingURL {
            content.userInfo = ["meetingURL": url.absoluteString, "eventId": event.id]
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(minutes) * 60,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "menucal-snooze-\(event.id)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func schedule(event: CalendarEvent, at fireDate: Date, minutesBefore: Int) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = minutesBefore == 0 ? "Starting now" : "Starts in \(minutesBefore) minute\(minutesBefore == 1 ? "" : "s")"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [
            "eventId": event.id,
            "meetingURL": event.meetingURL?.absoluteString ?? "",
        ]

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "menucal-\(event.id)-\(minutesBefore)m",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("MenuCal: failed to schedule notification for '\(event.title)': \(error)")
        }
    }
}
