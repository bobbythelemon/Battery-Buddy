import SwiftUI

@main
struct BatteryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                viewModel: appDelegate.viewModel,
                updaterController: appDelegate.updaterController
            )
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command])
            }
        }
    }
}
