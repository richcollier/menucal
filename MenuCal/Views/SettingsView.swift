import SwiftUI
import EventKit

struct SettingsView: View {
    @AppStorage("reminderMinutes")      var reminderMinutes: Int  = 5
    @AppStorage("notificationsEnabled") var notificationsEnabled  = true
    @AppStorage("hudEnabled")           var hudEnabled            = false
    @AppStorage("weekStartsOnMonday")   var weekStartsOnMonday    = false

    @StateObject private var tokenSettings = TokenSettingsManager.shared
    @EnvironmentObject var calendarService: EventKitService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    menubarSection
                    Divider().padding(.vertical, 4)
                    remindersSection
                    Divider().padding(.vertical, 4)
                    calendarsSection
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 320, height: 580)
        .onAppear { calendarService.loadAvailableCalendars() }
    }

    // MARK: - Menubar section

    private var menubarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Menubar Tokens")

            // Live preview
            HStack(spacing: 4) {
                Text("Preview:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(tokenSettings.previewString)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)

            // Token list (drag to reorder, toggle to enable)
            VStack(spacing: 0) {
                ForEach($tokenSettings.configs) { $config in
                    TokenRow(config: $config, allConfigs: $tokenSettings.configs)
                    if config.id != tokenSettings.configs.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            Text("Drag to reorder • Toggle to show/hide")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Reminders section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Reminders")

            VStack(spacing: 0) {
                HStack {
                    Text("Remind me")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $reminderMinutes) {
                        Text("1 min").tag(1)
                        Text("2 min").tag(2)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 12)

                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("System notification")
                            .font(.subheadline)
                        Text("Respects Focus and Do Not Disturb")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 12)

                Toggle(isOn: $hudEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Floating HUD")
                            .font(.subheadline)
                        Text("Always-on-top overlay, ignores Focus mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Calendars section

    private var calendarsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Calendars")

            VStack(spacing: 0) {
                Toggle(isOn: $weekStartsOnMonday) {
                    Text("Week starts on Monday")
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 12)
                if calendarService.availableCalendars.isEmpty {
                    Text("No calendars found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(12)
                }
                ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                    let isVisible = !calendarService.hiddenCalendarIDs.contains(calendar.calendarIdentifier)
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(calendar.cgColor))
                            .frame(width: 10, height: 10)
                            .padding(.leading, 12)
                        Text(calendar.title)
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isVisible },
                            set: { _ in calendarService.toggleCalendarVisibility(calendar.calendarIdentifier) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .scaleEffect(0.75)
                        .padding(.trailing, 4)
                    }
                    .padding(.vertical, 6)
                    if calendar.calendarIdentifier != calendarService.availableCalendars.last?.calendarIdentifier {
                        Divider().padding(.leading, 30)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
    }
}

// MARK: - Token row with drag handle and toggle

struct TokenRow: View {
    @Binding var config: TokenConfig
    @Binding var allConfigs: [TokenConfig]

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle (visual indicator)
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .frame(width: 16)
                .padding(.leading, 10)

            Image(systemName: config.token.icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(config.token.displayName)
                    .font(.subheadline)
                Text(config.token.example)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Up/down buttons for reordering
            HStack(spacing: 2) {
                Button {
                    moveToken(up: true)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(isFirst ? Color(NSColor.tertiaryLabelColor) : .secondary)
                .disabled(isFirst)

                Button {
                    moveToken(up: false)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(isLast ? Color(NSColor.tertiaryLabelColor) : .secondary)
                .disabled(isLast)
            }

            Toggle("", isOn: $config.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.75)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var currentIndex: Int {
        allConfigs.firstIndex(where: { $0.id == config.id }) ?? 0
    }
    private var isFirst: Bool { currentIndex == 0 }
    private var isLast:  Bool { currentIndex == allConfigs.count - 1 }

    private func moveToken(up: Bool) {
        let idx = currentIndex
        let dest = up ? idx - 1 : idx + 1
        guard dest >= 0, dest < allConfigs.count else { return }
        allConfigs.swapAt(idx, dest)
    }
}
