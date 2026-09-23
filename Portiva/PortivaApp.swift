import SwiftUI
final class AppDelegate: NSObject, NSApplicationDelegate {
    let workspace = WorkspaceModel()
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard workspace.hasActiveConnection else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Konsol oturumu açık"
        alert.informativeText = "Portiva'yı kapatmadan veya güncellemeden önce bağlantıyı kesin."
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
        return .terminateCancel
    }
}

@main
struct PortivaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("Portiva", id: "main") {
            ContentView(workspace: delegate.workspace)
        }
        .defaultSize(width: 1240, height: 820)
        Settings { SettingsView() }
    }
}
