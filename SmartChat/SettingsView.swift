import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.provider) private var providerRaw = AIProvider.openRouter.rawValue
    @AppStorage(AppSettings.model) private var model = AIProvider.openRouter.defaultModel
    @AppStorage(AppSettings.customModel) private var customModel = ""
    @AppStorage(AppSettings.apiKey) private var apiKey = ""
    @AppStorage(AppSettings.systemPrompt) private var systemPrompt = AppSettings.defaultSystemPrompt
    @AppStorage(AppSettings.temperature) private var temperature = AppSettings.defaultTemperature
    @AppStorage(AppSettings.maxTokens) private var maxTokens = AppSettings.defaultMaxTokens

    private var provider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .openRouter
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $providerRaw) {
                        ForEach(AIProvider.allCases) { item in
                            Text(item.rawValue).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Link("Get a free API key", destination: URL(string: provider.docsURL)!)
                        .font(.footnote)
                }

                Section("Model") {
                    Picker("Model", selection: $model) {
                        ForEach(provider.models, id: \.self) { item in
                            Text(item).tag(item)
                        }
                        Text("Custom…").tag("__custom__")
                    }
                    if model == "__custom__" {
                        TextField("Model name", text: $customModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("API key")
                } footer: {
                    Text(footerText)
                }

                Section("Behavior") {
                    Slider(
                        value: $temperature,
                        in: 0...2,
                        step: 0.1
                    ) {
                        Text("Temperature")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("2")
                    }
                    Text("Temperature: \(temperature, specifier: "%.1f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Stepper("Max tokens: \(maxTokens)", value: $maxTokens, in: 256...8192, step: 256)
                }

                Section("System prompt") {
                    TextField("System prompt", text: $systemPrompt, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Link("OpenRouter free models", destination: URL(string: "https://openrouter.ai/models?max_price=0")!)
                    Link("Gemini free tier", destination: URL(string: "https://aistudio.google.com")!)
                } header: {
                    Text("About free models")
                } footer: {
                    Text("This app never charges you. You only need a free API key from the provider. Keys are stored only on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: providerRaw) { _, _ in
                model = AIProvider(rawValue: providerRaw)?.defaultModel ?? AIProvider.openRouter.defaultModel
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var footerText: String {
        switch provider {
        case .openRouter:
            return "OpenRouter models marked \":free\" cost nothing. Create a free account and API key at openrouter.ai."
        case .gemini:
            return "Get a free Gemini API key at aistudio.google.com (the free tier includes gemini-2.5-flash)."
        }
    }
}