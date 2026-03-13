import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarId: String
    let calendarColor: Color
    let meetingURL: URL?
    let location: String?
    let attendees: [Attendee]
    let notes: String?
    let isGoogleCalendar: Bool

    var isPast: Bool { endDate < Date() }
    var isInProgress: Bool { startDate <= Date() && endDate > Date() }
    var minutesUntilStart: Int { max(0, Int(startDate.timeIntervalSinceNow / 60)) }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

struct Attendee: Identifiable, Equatable {
    let id: String        // email used as stable ID
    let name: String?
    let email: String
    let responseStatus: ResponseStatus
    let isSelf: Bool

    var displayName: String { name ?? email }

    enum ResponseStatus {
        case accepted, declined, tentative, needsAction
    }
}
