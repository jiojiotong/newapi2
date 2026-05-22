import Foundation

final class ChatService {
    private let baseURL: URL
    private var apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func fetchModels() async throws -> [String] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = basePath.isEmpty ? "/v1/models" : "/\(basePath)/v1/models"
        guard let url = components.url else { throw ChatError.serverError("URL 无效") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return response.data.map { $0.id }.sorted()
    }

    func sendMessage(model: String, messages: [ChatMessage]) async throws -> String {
        let url = try makeURL("/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        if let error = response.error {
            throw ChatError.serverError(error.message)
        }

        return response.choices?.first?.message?.content ?? ""
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
        let response = try JSONDecoder().decode(ImageResponse.self, from: data)
        return response.data?.first?.url ?? response.data?.first?.revisedPrompt ?? ""
    }

    private func makeURL(_ path: String) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
        guard let url = components.url else { throw ChatError.serverError("URL 无效") }
        return url
    }
}

// MARK: - Models

struct ModelsResponse: Decodable {
    let data: [ModelItem]
    struct ModelItem: Decodable {
        let id: String
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
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

    struct ImageData: Decodable {
        let url: String?
        let revisedPrompt: String?

        enum CodingKeys: String, CodingKey {
            case url
            case revisedPrompt = "revised_prompt"
        }
    }
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
