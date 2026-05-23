import Foundation

final class ChatService {
    private let baseURL: URL
    private var apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func fetchModels() async throws -> [ModelInfo] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = basePath.isEmpty ? "/v1/models" : "/\(basePath)/v1/models"
        guard let url = components.url else { throw ChatError.serverError("URL 无效") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return response.data.sorted { $0.id < $1.id }
    }

    func sendMessage(model: String, messages: [ChatMessage], imageBase64: String? = nil) async throws -> String {
        let url = try makeURL("/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(model: model, messages: buildRequestMessages(messages, imageBase64: imageBase64), stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response: ChatResponse
        do {
            response = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            if let message = serverMessage(from: data) {
                throw ChatError.serverError(message)
            }
            throw ChatError.serverError(error.localizedDescription)
        }

        if let error = response.error {
            throw ChatError.serverError(error.message)
        }

        return response.choices?.first?.message?.content ?? ""
    }

    func sendMessageStream(model: String, messages: [ChatMessage], imageBase64: String? = nil, onChunk: @MainActor @escaping (String) -> Void) async throws {
        let url = try makeURL("/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(model: model, messages: buildRequestMessages(messages, imageBase64: imageBase64), stream: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let bodyData = try await collectData(from: bytes)
            if let message = serverMessage(from: bodyData) {
                throw ChatError.serverError(message)
            }
            throw ChatError.serverError("请求失败")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            if jsonStr == "[DONE]" { break }
            guard let jsonData = jsonStr.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData) else {
                if let message = serverMessage(from: jsonStr.data(using: .utf8) ?? Data()) {
                    throw ChatError.serverError(message)
                }
                continue
            }
            if let content = chunk.choices?.first?.delta?.content {
                await onChunk(content)
            } else if let message = serverMessage(from: jsonData) {
                throw ChatError.serverError(message)
            }
        }
    }

    func buildRequestMessages(_ messages: [ChatMessage], imageBase64: String? = nil) -> [AnyChatMessage] {
        let trimmedMessages = messages.filter { message in
            !(message.role == "user" && message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        guard let imageBase64, !imageBase64.isEmpty, let last = messages.last, last.role == "user" else {
            return trimmedMessages.map { .text($0) }
        }

        let prefix = imageBase64.hasPrefix("data:") ? imageBase64 : "data:image/jpeg;base64,\(imageBase64)"
        let parts: [MultimodalMessage.ContentPart]
        if last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts = [MultimodalMessage.ContentPart(type: "image_url", text: nil, imageUrl: .init(url: prefix))]
        } else {
            parts = [
                MultimodalMessage.ContentPart(type: "text", text: last.content, imageUrl: nil),
                MultimodalMessage.ContentPart(type: "image_url", text: nil, imageUrl: .init(url: prefix))
            ]
        }

        let priorMessages = messages.dropLast().filter { message in
            !(message.role == "user" && message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        var requestMessages: [AnyChatMessage] = priorMessages.map { .text($0) }
        requestMessages.append(.multimodal(MultimodalMessage(role: last.role, content: parts)))
        return requestMessages
    }

    func generateImage(model: String, prompt: String, size: String) async throws -> String {
        let url = try makeURL("/v1/images/generations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ImageRequest(model: model, prompt: prompt, n: 1, size: size)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response: ImageResponse
        do {
            response = try JSONDecoder().decode(ImageResponse.self, from: data)
        } catch {
            if let message = serverMessage(from: data) {
                throw ChatError.serverError(message)
            }
            throw ChatError.serverError(error.localizedDescription)
        }
        if let error = response.error {
            throw ChatError.serverError(error.message)
        }
        if let url = response.data?.first?.url {
            return url
        }
        if let base64 = response.data?.first?.b64Json {
            return "data:image/png;base64,\(base64)"
        }
        return response.data?.first?.revisedPrompt ?? ""
    }

    private func makeURL(_ path: String) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
        guard let url = components.url else { throw ChatError.serverError("URL 无效") }
        return url
    }

    private func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private func serverMessage(from data: Data) -> String? {
        if let response = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
            return response.error?.message ?? response.message
        }
        return nil
    }
}

// MARK: - Models

struct ModelsResponse: Decodable {
    let data: [ModelInfo]
}

struct ModelInfo: Decodable, Identifiable {
    let id: String
    let contextLength: Int?
    let maxTokens: Int?

    var contextWindow: Int? {
        contextLength ?? maxTokens
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contextLength = "context_length"
        case maxTokens = "max_tokens"
        case maxContextLength = "max_context_length"
        case contextWindow = "context_window"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        contextLength = container.decodeIntIfPresent("context_length", "max_context_length", "context_window")
        maxTokens = container.decodeIntIfPresent("max_tokens")
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct MultimodalMessage: Encodable {
    let role: String
    let content: [ContentPart]

    struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageUrl: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageUrl = "image_url"
        }
    }

    struct ImageURL: Encodable {
        let url: String
    }
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [AnyChatMessage]
    let stream: Bool
}

enum AnyChatMessage: Encodable {
    case text(ChatMessage)
    case multimodal(MultimodalMessage)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let msg):
            try msg.encode(to: encoder)
        case .multimodal(let msg):
            try msg.encode(to: encoder)
        }
    }
}

struct ChatResponse: Decodable {
    let choices: [Choice]?
    let error: ChatResponseError?

    struct Choice: Decodable {
        let message: ChatMessage?
    }
}

struct ChatResponseError: Decodable {
    let message: String
}

struct ImageRequest: Encodable {
    let model: String
    let prompt: String
    let n: Int
    let size: String
}

struct ImageResponse: Decodable {
    let data: [ImageData]?
    let error: ChatResponseError?

    struct ImageData: Decodable {
        let url: String?
        let b64Json: String?
        let revisedPrompt: String?

        enum CodingKeys: String, CodingKey {
            case url
            case b64Json = "b64_json"
            case revisedPrompt = "revised_prompt"
        }
    }
}

struct ServerErrorResponse: Decodable {
    let error: ChatResponseError?
    let message: String?
}

enum ChatError: LocalizedError {
    case serverError(String)
    case noKey

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .noKey: return "请先选择一个令牌"
        }
    }
}

struct StreamChunk: Decodable {
    let choices: [StreamChoice]?

    struct StreamChoice: Decodable {
        let delta: StreamDelta?
    }

    struct StreamDelta: Decodable {
        let content: String?
    }
}
