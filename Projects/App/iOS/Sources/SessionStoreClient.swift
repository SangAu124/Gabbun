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
            let url = try Self.preparedStoreURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            // JSONDecoder를 매 호출마다 생성 — static 공유 시 동시 호출에서 thread-unsafe
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WakeSessionSummary].self, from: data)
        },
        save: { sessions in
            let url = try Self.preparedStoreURL()
            // JSONEncoder를 매 호출마다 생성 — static 공유 시 동시 호출에서 thread-unsafe
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: .atomic)
        }
    )

    public static let testValue = SessionStoreClient()

    // Application Support — 앱 삭제 전까지 유지
    // 매 호출마다 디렉토리 존재를 보장 (권한 문제 시 에러 전파)
    private static func preparedStoreURL() throws -> URL {
        // [0] 강제 접근 대신 .first 로 안전하게 처리 — 이론적으로는 항상 존재하지만 방어적 코드 유지
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[SessionStoreClient] Application Support 디렉토리를 찾을 수 없습니다")
            throw SessionStoreError.directoryNotFound
        }
        do {
            // withIntermediateDirectories: true — 이미 존재하면 무시
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("[SessionStoreClient] 저장 디렉토리 생성 실패: \(error.localizedDescription)")
            throw error
        }
        return dir.appendingPathComponent("wake_sessions.json")
    }

    private enum SessionStoreError: LocalizedError {
        case directoryNotFound
        var errorDescription: String? { "Application Support 디렉토리를 찾을 수 없습니다." }
    }
}

extension DependencyValues {
    public var sessionStoreClient: SessionStoreClient {
        get { self[SessionStoreClient.self] }
        set { self[SessionStoreClient.self] = newValue }
    }
}

// NOTE: JSONDecoder / JSONEncoder 인스턴스는 각 호출 내에서 생성하여 thread-safety를 보장합니다.
// (static 공유 인스턴스는 동시 다중 호출 시 데이터 경합 위험이 있습니다)
