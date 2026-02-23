import Foundation
import ComposableArchitecture
import SharedDomain

// MARK: - SessionStoreClient

@DependencyClient
public struct SessionStoreClient: Sendable {
    public var load: @Sendable () throws -> [WakeSessionSummary] = { [] }
    public var save: @Sendable ([WakeSessionSummary]) throws -> Void = { _ in }
}

// MARK: - DependencyKey

extension SessionStoreClient: DependencyKey {
    public static let liveValue = SessionStoreClient(
        load: {
            let url = Self.storeURL
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return try JSONDecoder.iso8601.decode([WakeSessionSummary].self, from: data)
        },
        save: { sessions in
            let data = try JSONEncoder.iso8601.encode(sessions)
            try data.write(to: Self.storeURL, options: .atomic)
        }
    )

    public static let testValue = SessionStoreClient()

    // Application Support — 앱 삭제 전까지 유지
    private static let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wake_sessions.json")
    }()
}

extension DependencyValues {
    public var sessionStoreClient: SessionStoreClient {
        get { self[SessionStoreClient.self] }
        set { self[SessionStoreClient.self] = newValue }
    }
}

// MARK: - Coders

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
