import SwiftUI
import SwiftData

@main
struct SmartChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Conversation.self, Message.self])
    }
}