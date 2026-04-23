import SwiftUI
import KeyTokCore

@main
struct KeyTokAppStoreApp: App {
    @NSApplicationDelegateAdaptor(AppStoreAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(coordinator: appDelegate.coordinator)
                .tint(.teal)
        } label: {
            MenuBarLabelView(coordinator: appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
