# MenuCal

A native macOS menubar app that surfaces your upcoming calendar events and lets you join meetings in one click — without opening a browser or full calendar app.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menubar display** — configurable tokens: event title, countdown timer, start time
- **One-click join** — branded Join buttons for Zoom, Google Meet, Teams, and WebEx
- **Mini calendar** — month view with dot indicators on days that have events
- **Day navigation** — Yesterday / Today / Tomorrow pills, plus arrows to navigate further
- **Linked resources** — surfaces Notion, GitHub, Figma, Google Docs/Sheets/Slides links from event descriptions
- **Calendar filtering** — show/hide individual calendars from Settings
- **Open in Google Calendar** — deep link to the right day for Google calendar events
- **Privacy-first** — reads directly from macOS Calendar via EventKit, no accounts or cloud services required

## Requirements

- macOS 13 Ventura or later
- Calendars synced to the macOS Calendar app (System Settings → Internet Accounts)

## Installation

### Download (easiest)

1. Download `MenuCal.zip` from the [latest release](../../releases/latest)
2. Unzip and drag `MenuCal.app` to your Applications folder
3. Right-click → Open on first launch (macOS requires this for apps outside the App Store)

### Build from source

1. Clone this repo
2. Open `MenuCal.xcodeproj` in Xcode 15+
3. Select your team in Signing & Capabilities
4. Product → Run

## First launch

MenuCal will ask for Calendar access — grant it in the system prompt that appears. If you miss it, go to System Settings → Privacy & Security → Calendars.

## Settings

Click the gear icon in the popover header to open Settings:
- **Menubar tokens** — choose what appears in the menubar and in what order
- **Reminder** — optional alert before meetings start
- **Calendars** — toggle individual calendars on/off

## Privacy

MenuCal reads your calendar data locally via Apple's EventKit framework. No data leaves your device.
