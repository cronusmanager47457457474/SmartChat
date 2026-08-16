import Foundation

struct AIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class AIService {
    static let shared = AIService()
    private init() {}

    func stream(
        provider: AIProvider,
        model: String,
        systemPrompt: String,
        messages: [Message],
        apiKey: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        switch provider {
        case .openRouter:
            return try await streamOpenRouter(
                model: model,
                systemPrompt: systemPrompt,
                messages: messages,
                apiKey: apiKey,
                temperature: temperature,
                maxTokens: maxTokens
            )
        case .gemini:
            return try await streamGemini(
                model: model,
                systemPrompt: systemPrompt,
                messages: messages,
                apiKey: apiKey,
                temperature: temperature,
                maxTokens: maxTokens
            )
        }
    }

    // MARK: - OpenRouter (OpenAI-compatible chat completions)

    private func streamOpenRouter(
        model: String,
        systemPrompt: String,
        messages: [Message],
        apiKey: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("smartchat-app", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": buildOpenRouterMessages(systemPrompt: systemPrompt, messages: messages),
            "stream": true,
            "temperature": temperature,
            "max_tokens": maxTokens
        ])

        return AsyncThrowingStream { continuation in
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    let body = try? await bytes.reduce(into: "") { $0.append(String(decoding: $1, as: UTF8.self)) }
                    let message = extractErrorMessage(body: body) ?? "Server returned HTTP \(http.statusCode)"
                    continuation.finish(throwing: AIError(message: message))
                    return
                }
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !json.isEmpty else { continue }
                    if json == "[DONE]" { break }
                    if let token = parseOpenRouterDelta(json: json), !token.isEmpty {
                        continuation.yield(token)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: mapURLError(error))
            }
        }
    }

    private func parseOpenRouterDelta(json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }

    private func buildOpenRouterMessages(systemPrompt: String, messages: [Message]) -> [[String: Any]] {
        var payload: [[String: Any]] = []
        if !systemPrompt.isEmpty {
            payload.append(["role": "system", "content": systemPrompt])
        }
        for message in messages where !message.content.isEmpty || message.imageData != nil {
            if let image = message.imageData, message.isUser {
                payload.append([
                    "role": "user",
                    "content": [
                        ["type": "text", "text": message.content],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(image.base64EncodedString())"]]
                    ]
                ])
            } else {
                payload.append(["role": message.role, "content": message.content])
            }
        }
        return payload
    }

    // MARK: - Gemini (Google Generative Language API)

    private func streamGemini(
        model: String,
        systemPrompt: String,
        messages: [Message],
        apiKey: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent")!
        components.queryItems = [
            URLQueryItem(name: "alt", value: "sse"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "contents": buildGeminiContents(messages: messages),
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]
        if !systemPrompt.isEmpty {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return AsyncThrowingStream { continuation in
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    let body = try? await bytes.reduce(into: "") { $0.append(String(decoding: $1, as: UTF8.self)) }
                    let message = extractErrorMessage(body: body) ?? "Server returned HTTP \(http.statusCode)"
                    continuation.finish(throwing: AIError(message: message))
                    return
                }
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !json.isEmpty else { continue }
                    if let token = parseGeminiToken(json: json), !token.isEmpty {
                        continuation.yield(token)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: mapURLError(error))
            }
        }
    }

    private func parseGeminiToken(json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        if let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            return tokenFromGeminiResponse(obj)
        }
        if let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]], let obj = arr.first {
            return tokenFromGeminiResponse(obj)
        }
        return nil
    }

    private func tokenFromGeminiResponse(_ obj: [String: Any]) -> String? {
        guard let candidates = obj["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text
    }

    private func buildGeminiContents(messages: [Message]) -> [[String: Any]] {
        var payload: [[String: Any]] = []
        for message in messages where !message.content.isEmpty || message.imageData != nil {
            var parts: [[String: Any]] = []
            if let image = message.imageData {
                parts.append(["inline_data": ["mime_type": "image/jpeg", "data": image.base64EncodedString()]])
            }
            if !message.content.isEmpty {
                parts.append(["text": message.content])
            }
            payload.append(["role": message.isUser ? "user" : "model", "parts": parts])
        }
        return payload
    }

    // MARK: - Helpers

    private func extractErrorMessage(body: String?) -> String? {
        guard let body,
              let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }

    private func mapURLError(_ error: Error) -> Error {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return error }
        switch ns.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            return AIError(message: "Could not reach the AI server. Check your internet connection and try again.")
        case NSURLErrorTimedOut:
            return AIError(message: "The request timed out. Try again.")
        default:
            return AIError(message: "Network error (\(ns.code)). Try again.")
        }
    }
}