import Foundation
import SwiftData
import SwiftUI
import Observation
import PhotosUI
import UIKit

@MainActor
@Observable
final class ChatViewModel {
    let conversation: Conversation
    private let modelContext: ModelContext
    private let service = AIService.shared

    var input: String = ""
    var isStreaming = false
    var pendingImage: UIImage?
    var errorMessage: String?

    private var task: Task<Void, Never>?

    init(conversation: Conversation, modelContext: ModelContext) {
        self.conversation = conversation
        self.modelContext = modelContext
    }

    var messages: [Message] { conversation.sortedMessages }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming else { return }
        guard !text.isEmpty || pendingImage != nil else { return }

        let userMessage = Message(role: "user", content: text, imageData: pendingImage?.jpegData(compressionQuality: 0.8))
        pendingImage = nil
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        if conversation.messages.count == 1 {
            conversation.title = text.isEmpty ? "Image message" : String(text.prefix(40))
        }
        input = ""
        save()
        Task { await streamReply() }
    }

    func regenerate() {
        guard messages.contains(where: { $0.isUser }) else { return }
        if let lastAssistant = messages.last(where: { !$0.isUser }) {
            conversation.messages.removeAll { $0 === lastAssistant }
            modelContext.delete(lastAssistant)
            save()
        }
        Task { await streamReply() }
    }

    func stop() {
        task?.cancel()
        isStreaming = false
    }

    func streamReply() async {
        guard !isStreaming else { return }
        isStreaming = true
        errorMessage = nil

        let assistant = Message(role: "assistant", content: "")
        modelContext.insert(assistant)
        conversation.messages.append(assistant)
        save()

        let history = conversation.sortedMessages.filter { $0 !== assistant }
        task = Task {
            do {
                let settings = currentSettings()
                guard !settings.apiKey.isEmpty else {
                    throw AIError(message: "Add your API key in Settings to start chatting.")
                }
                let replyStream = try await service.stream(
                    provider: settings.provider,
                    model: settings.model,
                    systemPrompt: settings.systemPrompt,
                    messages: history,
                    apiKey: settings.apiKey,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                for try await token in replyStream {
                    try Task.checkCancellation()
                    assistant.content += token
                    save()
                }
                if assistant.content.isEmpty {
                    assistant.error = "The model returned an empty response. Try again or pick a different model in Settings."
                    save()
                }
            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch {
                assistant.error = friendlyMessage(for: error)
            }
            isStreaming = false
            save()
        }
    }

    struct RuntimeSettings {
        let provider: AIProvider
        let model: String
        let systemPrompt: String
        let apiKey: String
        let temperature: Double
        let maxTokens: Int
    }

    func currentSettings() -> RuntimeSettings {
        let defaults = UserDefaults.standard
        let provider = AIProvider(rawValue: defaults.string(forKey: AppSettings.provider) ?? "") ?? .openRouter
        let model = defaults.string(forKey: AppSettings.model) ?? provider.defaultModel
        let customModel = defaults.string(forKey: AppSettings.customModel) ?? ""
        let resolvedModel = model == "__custom__" ? customModel : model
        let systemPrompt = defaults.string(forKey: AppSettings.systemPrompt) ?? AppSettings.defaultSystemPrompt
        let apiKey = defaults.string(forKey: AppSettings.apiKey) ?? ""
        let temperature = defaults.object(forKey: AppSettings.temperature) as? Double ?? AppSettings.defaultTemperature
        let maxTokens = defaults.object(forKey: AppSettings.maxTokens) as? Int ?? AppSettings.defaultMaxTokens
        return RuntimeSettings(
            provider: provider,
            model: resolvedModel,
            systemPrompt: systemPrompt,
            apiKey: apiKey,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    private func save() {
        try? modelContext.save()
    }

    private func friendlyMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

struct ChatView: View {
    let conversation: Conversation
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ChatScreen(viewModel: viewModel)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(conversation: conversation, modelContext: modelContext)
            }
        }
    }
}

@MainActor
struct ChatScreen: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showSettings = false
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            inputBar
        }
        .navigationTitle(viewModel.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .contextMenu {
                                if !message.content.isEmpty {
                                    Button("Copy") { UIPasteboard.general.string = message.content }
                                    ShareLink(item: message.content)
                                }
                                if !message.isUser {
                                    Button("Regenerate") { viewModel.regenerate() }
                                }
                            }
                    }
                    if viewModel.isStreaming {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .id("streaming-indicator")
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.content.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let image = viewModel.pendingImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        viewModel.pendingImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                }
                TextField("Message", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                if viewModel.isStreaming {
                    Button {
                        viewModel.stop()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        viewModel.send()
                        inputFocused = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(canSend ? Color.accentColor : Color.gray.opacity(0.4))
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(.bar)
        .onChange(of: pickerItem) { _, _ in
            loadPickerItem()
        }
    }

    private var canSend: Bool {
        !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.pendingImage != nil
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = viewModel.messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        } else if viewModel.isStreaming {
            withAnimation { proxy.scrollTo("streaming-indicator", anchor: .bottom) }
        }
    }

    private func loadPickerItem() {
        guard let pickerItem else { return }
        Task {
            if let data = try? await pickerItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.pendingImage = image
            }
            self.pickerItem = nil
        }
    }
}