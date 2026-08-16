import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @State private var path = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView {
                        Label("No chats yet", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Start a chat with free AI models.")
                    } actions: {
                        Button("New Chat") { createNewChat() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(value: conversation) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(conversation.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    if let preview = conversation.sortedMessages.last?.content, !preview.isEmpty {
                                        Text(preview)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("SmartChat")
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    private func createNewChat() {
        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        path.append(conversation)
    }

    private func delete(_ conversation: Conversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
}