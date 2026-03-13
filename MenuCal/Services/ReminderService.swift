import Foundation
import Combine

/// Coordinates NotificationService and HUDService.
/// AppDelegate creates this, calls start(observing:), and is done.
@MainActor
class ReminderService {

    let notificationService = NotificationService()
    private(set) lazy var hudService = HUDService(notificationService: notificationService)

    private var cancellables = Set<AnyCancellable>()

    func start(observing calendarService: EventKitService) {
        hudService.start(observing: calendarService)

        // Re-schedule system notifications whenever the event list updates
        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                guard let self else { return }
                guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
                    self.notificationService.cancelAll()
                    return
                }
                let minutesBefore = UserDefaults.standard.integer(forKey: "reminderMinutes")
                Task { await self.notificationService.scheduleReminders(for: events, minutesBefore: minutesBefore) }
            }
            .store(in: &cancellables)
    }
}
