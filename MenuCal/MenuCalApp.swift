import SwiftUI

@main
struct MenuCalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // A Settings scene is required to satisfy SwiftUI's App protocol.
        // The real UI lives in the menubar via AppDelegate.
        Settings { EmptyView() }
    }
}
