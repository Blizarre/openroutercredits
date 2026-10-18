import XCTest

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
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

final class OpenRouterAPIClientTests: XCTestCase {
    private var client: OpenRouterAPIClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        client = OpenRouterAPIClient(session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        client = nil
        super.tearDown()
    }

    func testDecodesSuccessfulResponse() async throws {
        MockURLProtocol.handler = { request in
            let data = Data(#"{"data":{"total_credits":100.5,"total_usage":25.75}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let snapshot = try await client.fetchCredits(apiKey: "test-key")

        XCTAssertEqual(snapshot.remaining, Decimal(string: "74.75"))
    }

    func testSendsBearerTokenAndEndpoint() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            let data = Data(#"{"data":{"total_credits":1,"total_usage":0}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        _ = try await client.fetchCredits(apiKey: "secret-key")

        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://openrouter.ai/api/v1/credits")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-key")
    }

    func testUnauthorized() async {
        await assertError(statusCode: 401, equals: .unauthorized)
    }

    func testForbidden() async {
        await assertError(statusCode: 403, equals: .forbidden)
    }

    func testServerError() async {
        await assertError(statusCode: 500, equals: .server(statusCode: 500))
    }

    func testRateLimitIncludesRetryAfter() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "120"]
            )!
            return (response, Data())
        }

        do {
            _ = try await client.fetchCredits(apiKey: "key")
            XCTFail("Expected rateLimited error")
        } catch let error as CreditsError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 120))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOfflineMapsToNetworkError() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.fetchCredits(apiKey: "key")
            XCTFail("Expected network error")
        } catch let error as CreditsError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedJSONMapsToDecodingError() async {
        MockURLProtocol.handler = { request in
            let data = Data("not json".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        do {
            _ = try await client.fetchCredits(apiKey: "key")
            XCTFail("Expected decoding error")
        } catch let error as CreditsError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func assertError(statusCode: Int, equals expected: CreditsError) async {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await client.fetchCredits(apiKey: "key")
            XCTFail("Expected error for status \(statusCode)")
        } catch let error as CreditsError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
