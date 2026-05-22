import Foundation

final class NewAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func get<DataType: Decodable>(_ path: String) async throws -> DataType {
        try await request(path, method: "GET", queryItems: [], body: Optional<EmptyRequest>.none)
    }

    func get<DataType: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> DataType {
        try await request(path, method: "GET", queryItems: queryItems, body: Optional<EmptyRequest>.none)
    }

    func post<Body: Encodable, DataType: Decodable>(_ path: String, body: Body) async throws -> DataType {
        try await request(path, method: "POST", queryItems: [], body: body)
    }

    func put<Body: Encodable, DataType: Decodable>(_ path: String, body: Body) async throws -> DataType {
        try await request(path, method: "PUT", queryItems: [], body: body)
    }

    func delete<DataType: Decodable>(_ path: String) async throws -> DataType {
        try await request(path, method: "DELETE", queryItems: [], body: Optional<EmptyRequest>.none)
    }

    private func request<Body: Encodable, DataType: Decodable>(_ path: String, method: String, queryItems: [URLQueryItem], body: Body?) async throws -> DataType {
        let url = try makeURL(path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NewAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 401:
                throw NewAPIError.unauthorized
            case 403:
                throw NewAPIError.forbidden
            case 200..<300:
                break
            default:
                throw NewAPIError.invalidResponse
            }

            do {
                let apiResponse = try decoder.decode(NewAPIResponse<DataType>.self, from: data)
                guard apiResponse.success else {
                    throw NewAPIError.serverMessage(apiResponse.message)
                }
                guard let responseData = apiResponse.data else {
                    if DataType.self == EmptyResponseData.self, let empty = EmptyResponseData() as? DataType {
                        return empty
                    }
                    throw NewAPIError.missingData
                }
                return responseData
            } catch let error as NewAPIError {
                throw error
            } catch {
                throw NewAPIError.decoding(error.localizedDescription)
            }
        } catch let error as NewAPIError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                throw NewAPIError.timeout
            }
            throw NewAPIError.network(error.localizedDescription)
        }
    }

    func makeURL(_ path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NewAPIError.invalidServerURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath: String
        var mergedQueryItems = queryItems

        if let pathComponents = URLComponents(string: path), let parsedPath = pathComponents.path.nilIfEmpty {
            requestPath = parsedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            mergedQueryItems.append(contentsOf: pathComponents.queryItems ?? [])
        } else {
            requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        components.path = "/" + [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
        let existingQueryItems = components.queryItems ?? []
        let allQueryItems = existingQueryItems + mergedQueryItems
        if !allQueryItems.isEmpty {
            components.queryItems = allQueryItems
        }

        guard let url = components.url else {
            throw NewAPIError.invalidServerURL
        }
        return url
    }
}

private struct EmptyRequest: Encodable {}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
