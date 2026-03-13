import EventKit
import SwiftUI
import Combine

@MainActor
class EventKitService: ObservableObject {

    @Published var events: [CalendarEvent] = []          // for the selected date (popover)
    @Published var todayEvents: [CalendarEvent] = []     // always today (menubar)
    @Published var isLoading = false
    @Published var lastError: String? = nil
    @Published var lastRefreshed: Date? = nil
    @Published var accessGranted = false
    @Published var selectedDate = Date()
    @Published var eventDaysInMonth: Set<String> = []
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hiddenCalendarIDs: Set<String> = {
        let arr = UserDefaults.standard.stringArray(forKey: "hiddenCalendarIDs") ?? []
        return Set(arr)
    }()

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    init() {
        accessGranted = Self.isCurrentlyAuthorized

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    // MARK: - Authorization

    private static var isCurrentlyAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    func toggleCalendarVisibility(_ calendarID: String) {
        if hiddenCalendarIDs.contains(calendarID) {
            hiddenCalendarIDs.remove(calendarID)
        } else {
            hiddenCalendarIDs.insert(calendarID)
        }
        UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: "hiddenCalendarIDs")
        Task { await fetchTodaysEvents() }
    }

    func requestAccessAndFetch() async {
        if accessGranted {
            loadAvailableCalendars()
            await fetchTodayEventsInternal()
            if !Calendar.current.isDateInToday(selectedDate) {
                await fetchEvents(for: selectedDate)
            }
            startAutoRefresh()
            return
        }

        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { cont in
                    store.requestAccess(to: .event) { ok, err in
                        if let err { cont.resume(throwing: err) } else { cont.resume(returning: ok) }
                    }
                }
            }
            accessGranted = granted
            if granted {
                loadAvailableCalendars()
                await fetchEvents(for: selectedDate)
                startAutoRefresh()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Date selection

    func selectDate(_ date: Date) async {
        selectedDate = date
        await fetchEvents(for: date)
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                Task { await self.autoRefresh() }
            }
        }
    }

    private func autoRefresh() async {
        // Always refresh today for the menubar
        await fetchTodayEventsInternal()
        // Also refresh the selected date if it's not today
        if !Calendar.current.isDateInToday(selectedDate) {
            await fetchEvents(for: selectedDate)
        }
    }

    // MARK: - Fetch events for a day

    func fetchTodaysEvents() async {
        await fetchTodayEventsInternal()
        if !Calendar.current.isDateInToday(selectedDate) {
            await fetchEvents(for: selectedDate)
        }
    }

    private func fetchTodayEventsInternal() async {
        guard accessGranted else { return }
        let fetched = fetchEKEvents(for: Date())
        todayEvents = fetched
        // Mirror into events if today is the selected date
        if Calendar.current.isDateInToday(selectedDate) {
            events = fetched
            lastRefreshed = Date()
        }
    }

    func fetchEvents(for date: Date) async {
        guard accessGranted else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let fetched = fetchEKEvents(for: date)
        events = fetched
        if Calendar.current.isDateInToday(date) { todayEvents = fetched }
        lastRefreshed = Date()
    }

    func loadAvailableCalendars() {
        availableCalendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func fetchEKEvents(for date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        let calendarsArg: [EKCalendar]?
        if hiddenCalendarIDs.isEmpty {
            calendarsArg = nil
        } else {
            let visible = store.calendars(for: .event)
                .filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
            if visible.isEmpty { return [] }
            calendarsArg = visible
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendarsArg)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .compactMap { mapEvent($0) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Fetch event days for month (dot indicators)

    func refreshEventDays(for month: Date) async {
        guard accessGranted else { return }

        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let end   = cal.date(byAdding: .month, value: 1, to: start)!

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents  = store.events(matching: predicate)

        var days = Set<String>()
        for event in ekEvents where event.status != .canceled {
            if let date = event.startDate {
                days.insert(DateFormatters.dateOnly.string(from: date))
            }
        }
        eventDaysInMonth = days
    }

    @objc private func storeChanged() {
        Task { await autoRefresh() }
    }

    // MARK: - EKEvent → CalendarEvent

    private func mapEvent(_ ek: EKEvent) -> CalendarEvent? {
        guard let start = ek.startDate, let end = ek.endDate else { return nil }

        let color: Color = ek.calendar.cgColor.map { Color($0) } ?? .accentColor

        let sourceTitle = ek.calendar.source.title.lowercased()
        let isGoogle = ek.calendar.source.sourceType == .calDAV &&
            (sourceTitle.contains("google") || sourceTitle.contains("gmail") || sourceTitle.contains("@"))

        return CalendarEvent(
            id: ek.eventIdentifier ?? UUID().uuidString,
            title: ek.title ?? "Untitled",
            startDate: start,
            endDate: end,
            isAllDay: ek.isAllDay,
            calendarId: ek.calendar.calendarIdentifier,
            calendarColor: color,
            meetingURL: extractMeetingURL(from: ek),
            location: ek.location?.nilIfEmpty,
            attendees: (ek.attendees ?? []).map { mapParticipant($0) },
            notes: ek.notes?.nilIfEmpty,
            isGoogleCalendar: isGoogle
        )
    }

    private func extractMeetingURL(from ek: EKEvent) -> URL? {
        if let url = ek.url {
            let s = url.absoluteString.lowercased()
            if s.contains("meet.google") || s.contains("tel.meet") || s.contains("zoom.us") || s.contains("teams.microsoft") || s.contains("webex") {
                return url
            }
        }
        return MeetingURLDetector.extractURL(fromNotes: ek.notes, location: ek.location)
    }

    private func mapParticipant(_ p: EKParticipant) -> Attendee {
        let email = p.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")

        let status: Attendee.ResponseStatus
        switch p.participantStatus {
        case .accepted:   status = .accepted
        case .declined:   status = .declined
        case .tentative:  status = .tentative
        default:          status = .needsAction
        }

        return Attendee(
            id: email,
            name: p.name,
            email: email,
            responseStatus: status,
            isSelf: p.isCurrentUser
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
