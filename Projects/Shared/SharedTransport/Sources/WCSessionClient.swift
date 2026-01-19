import Foundation
import ComposableArchitecture

// MARK: - WCSessionClient
// TCA Dependency로 설계된 WatchConnectivity 클라이언트
// iOS/watchOS 간 TransportMessage 송수신 담당
@DependencyClient
public struct WCSessionClient: Sendable {
    // 메시지 수신 스트림 (AsyncStream)
    public var messages: @Sendable () -> AsyncStream<TransportMessage> = { .finished }

    // 메시지 전송
    public var send: @Sendable (_ message: TransportMessage) async throws -> Void

    // 상대방 기기 도달 가능 여부
    public var isReachable: @Sendable () -> Bool = { false }

    // 활성화 여부 (iOS: isPaired && isWatchAppInstalled, watchOS: isCompanionAppInstalled)
    public var isActivated: @Sendable () -> Bool = { false }

    // WCSession 활성화 (앱 시작 시 호출)
    public var activate: @Sendable () async -> Void
}

// MARK: - DependencyKey
extension WCSessionClient: TestDependencyKey {
    public static var testValue: WCSessionClient {
        return WCSessionClient()
    }

    public static var previewValue: WCSessionClient {
        return WCSessionClient.mock()
    }
}

extension DependencyValues {
    public var wcSessionClient: WCSessionClient {
        get { self[WCSessionClient.self] }
        set { self[WCSessionClient.self] = newValue }
    }
}
