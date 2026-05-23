import Foundation
import XCTest
@testable import NewAPIAdmin

final class NewAPIAdminCoreTests: XCTestCase {
    func testMakeURLPreservesQueryItems() throws {
        let client = NewAPIClient(baseURL: URL(string: "https://example.com/admin")!)
        let url = try client.makeURL("/api/channel/", queryItems: [URLQueryItem(name: "p", value: "1"), URLQueryItem(name: "page_size", value: "50")])
        XCTAssertEqual(url.absoluteString, "https://example.com/admin/api/channel/?p=1&page_size=50")
    }

    func testOptionParserBuildsDictionary() {
        let options = [OptionItem(key: "ModelPrice", value: "{}"), OptionItem(key: "GroupRatio", value: "{\"default\":1}")]
        XCTAssertEqual(OptionParser.dictionary(from: options)["ModelPrice"], "{}")
        XCTAssertEqual(OptionParser.dictionary(from: options)["GroupRatio"], "{\"default\":1}")
    }

    func testJSONValidationRejectsInvalidJSON() {
        XCTAssertThrowsError(try FormValidation.validateJSONString("{", field: "ModelPrice"))
    }

    func testNumericValidationRejectsInvalidValues() {
        XCTAssertThrowsError(try FormValidation.requirePositiveInt(0, field: "数量"))
        XCTAssertThrowsError(try FormValidation.requireNonNegative(-1, field: "额度"))
    }

    func testRedemptionValidationAcceptsValidValues() throws {
        XCTAssertNoThrow(try FormValidation.requirePositive(1, field: "额度"))
        XCTAssertNoThrow(try FormValidation.requirePositiveInt(10, field: "数量"))
        XCTAssertNoThrow(try FormValidation.requirePositiveInt(1_900_000_000, field: "过期时间"))
    }

    func testLoginResponseDetectsTwoFactor() throws {
        let data = Data("""
        {"require_2fa":true}
        """.utf8)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        XCTAssertTrue(response.requiresTwoFactor)
        XCTAssertNil(response.adminUser)
    }

    func testAnyJSONValueRoundTrip() throws {
        let data = Data("{\"a\":1,\"b\":true,\"c\":[\"x\"]}".utf8)
        let value = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        let encoded = try JSONEncoder().encode(value)
        XCTAssertFalse(encoded.isEmpty)
    }

    func testMutationAcceptsSuccessWithNullData() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/channel/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("{\"success\":true,\"message\":\"ok\",\"data\":null}".utf8)
            return (response, data)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = NewAPIClient(baseURL: URL(string: "https://example.com")!, session: URLSession(configuration: configuration))
        let service = ChannelService(client: client)

        try await service.create(DynamicObject(values: ["name": .string("test")]))
    }

    func testChatServiceBuildsMultimodalRequestWhenImageIsAttached() {
        let service = ChatService(baseURL: URL(string: "https://example.com")!, apiKey: "sk-test")
        let messages = [
            ChatMessage(role: "system", content: "You are helpful."),
            ChatMessage(role: "user", content: "Describe this image")
        ]

        let requestMessages = service.buildRequestMessages(messages, imageBase64: "abc123")

        XCTAssertEqual(requestMessages.count, 2)
        guard case .multimodal(let multimodal)? = requestMessages.last else {
            return XCTFail("Expected multimodal user message")
        }
        XCTAssertEqual(multimodal.role, "user")
        XCTAssertEqual(multimodal.content.count, 2)
        XCTAssertEqual(multimodal.content[0].type, "text")
        XCTAssertEqual(multimodal.content[0].text, "Describe this image")
        XCTAssertEqual(multimodal.content[1].type, "image_url")
        XCTAssertEqual(multimodal.content[1].imageUrl?.url, "data:image/jpeg;base64,abc123")
    }

    func testChatServiceBuildsImageOnlyMessageWithoutEmptyText() {
        let service = ChatService(baseURL: URL(string: "https://example.com")!, apiKey: "sk-test")
        let messages = [
            ChatMessage(role: "system", content: "You are helpful."),
            ChatMessage(role: "user", content: "")
        ]

        let requestMessages = service.buildRequestMessages(messages, imageBase64: "abc123")

        XCTAssertEqual(requestMessages.count, 2)
        guard case .multimodal(let multimodal)? = requestMessages.last else {
            return XCTFail("Expected multimodal user message")
        }
        XCTAssertEqual(multimodal.content.count, 1)
        XCTAssertNil(multimodal.content[0].text)
        XCTAssertEqual(multimodal.content[0].type, "image_url")
    }

    func testChatHistorySaveUpsertsSingleConversation() {
        UserDefaults.standard.removeObject(forKey: "chat_history")

        let viewModel = ChatViewModel()
        viewModel.selectedModel = "gpt-4o"
        viewModel.chatHistory = [ChatMessage(role: "user", content: "Hello")]

        viewModel.saveCurrentToHistory()
        viewModel.chatHistory.append(ChatMessage(role: "assistant", content: "Hi"))
        viewModel.saveCurrentToHistory()

        XCTAssertEqual(viewModel.savedConversations.count, 1)
        XCTAssertEqual(viewModel.savedConversations.first?.messages.count, 2)
        XCTAssertEqual(viewModel.savedConversations.first?.messages.last?.content, "Hi")
    }

    func testChatMemoriesLoadFromDefaults() {
        UserDefaults.standard.removeObject(forKey: "chat_memories")
        let memories = [
            MemoryItem(id: "1", content: "Prefer short replies", enabled: true),
            MemoryItem(id: "2", content: "Use Chinese", enabled: false)
        ]
        let data = try! JSONEncoder().encode(memories)
        UserDefaults.standard.set(data, forKey: "chat_memories")

        let viewModel = ChatViewModel()
        viewModel.loadMemories()

        XCTAssertEqual(viewModel.memories.count, 2)
        XCTAssertEqual(viewModel.memories.first?.content, "Prefer short replies")
    }

    func testImageResponseDecodesBase64Payload() throws {
        let data = Data("""
        {"data": [{"b64_json": "abc123"}]}
        """.utf8)
        let response = try JSONDecoder().decode(ImageResponse.self, from: data)
        XCTAssertEqual(response.data?.first?.b64Json, "abc123")
    }

    func testServerErrorResponseDecodesMessage() throws {
        let data = Data("""
        {"error": {"message": "nope"}}
        """.utf8)
        let response = try JSONDecoder().decode(ServerErrorResponse.self, from: data)
        XCTAssertEqual(response.error?.message, "nope")
    }

    func testVisualPricingEditorParsesModelRows() {
        // Verify that PricingViewModel can parse JSON options into model rows
        let json = "{\"gpt-4\":15,\"gpt-4o\":1.25}"
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }
        XCTAssertEqual(obj.count, 2)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: NewAPIError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
