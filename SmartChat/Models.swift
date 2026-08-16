import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(title: String = "New Chat", createdAt: Date = Date()) {
        self.title = title
        self.createdAt = createdAt
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class Message {
    var id: UUID = UUID()
    var role: String = "user"
    var content: String = ""
    var createdAt: Date = Date()
    var error: String?
    var imageData: Data?
    var conversation: Conversation?

    init(role: String, content: String, createdAt: Date = Date(), imageData: Data? = nil) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.imageData = imageData
    }

    var isUser: Bool { role == "user" }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openRouter = "OpenRouter"
    case gemini = "Gemini"

    var id: String { rawValue }

    var docsURL: String {
        switch self {
        case .openRouter: return "https://openrouter.ai"
        case .gemini: return "https://aistudio.google.com"
        }
    }

    static let openRouterFreeModels: [String] = [
        "deepseek/deepseek-chat-v3-0324:free",
        "meta-llama/llama-3.3-70b-instruct:free",
        "qwen/qwen-2.5-72b-instruct:free",
        "google/gemma-3-27b-it:free",
        "microsoft/phi-4:free",
        "mistralai/mistral-7b-instruct:free"
    ]

    static let geminiFreeModels: [String] = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash"
    ]

    var models: [String] {
        switch self {
        case .openRouter: return AIProvider.openRouterFreeModels
        case .gemini: return AIProvider.geminiFreeModels
        }
    }

    var defaultModel: String {
        switch self {
        case .openRouter: return AIProvider.openRouterFreeModels[0]
        case .gemini: return AIProvider.geminiFreeModels[0]
        }
    }
}

enum AppSettings {
    static let apiKey = "apiKey"
    static let provider = "provider"
    static let model = "model"
    static let customModel = "customModel"
    static let temperature = "temperature"
    static let maxTokens = "maxTokens"
    static let systemPrompt = "systemPrompt"

    static let defaultSystemPrompt = "You are a helpful, friendly AI assistant. Be concise but thorough, and format answers with Markdown when helpful."
    static let defaultTemperature = 0.7
    static let defaultMaxTokens = 4096
}