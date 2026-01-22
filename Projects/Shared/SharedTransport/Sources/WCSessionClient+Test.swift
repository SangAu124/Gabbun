import Foundation

// MARK: - Mock Implementation
extension WCSessionClient {
    // 테스트/프리뷰용 Mock 클라이언트
    public static func mock(
        isReachable: Bool = true,
        isActivated: Bool = true
    ) -> Self {
        let (stream, continuation) = AsyncStream<TransportMessage>.makeStream()

        return WCSessionClient(
            messages: { stream },
            send: { message in
                // Mock 전송: continuation을 통해 즉시 에코백 (테스트용)
                continuation.yield(message)
            },
            updateContext: { message in
                // Mock: 즉시 에코백
                continuation.yield(message)
            },
            receivedContext: { nil },
            isReachable: { isReachable },
            isActivated: { isActivated },
            activate: {}
        )
    }

    // 커스터마이징 가능한 Mock
    public static func testMock(
        messages: AsyncStream<TransportMessage> = .finished,
        send: @escaping @Sendable (TransportMessage) async throws -> Void = { _ in },
        updateContext: @escaping @Sendable (TransportMessage) throws -> Void = { _ in },
        receivedContext: @escaping @Sendable () -> TransportMessage? = { nil },
        isReachable: @escaping @Sendable () -> Bool = { true },
        isActivated: @escaping @Sendable () -> Bool = { true },
        activate: @escaping @Sendable () async -> Void = {}
    ) -> Self {
        return WCSessionClient(
            messages: { messages },
            send: send,
            updateContext: updateContext,
            receivedContext: receivedContext,
            isReachable: isReachable,
            isActivated: isActivated,
            activate: activate
        )
    }

    // 항상 실패하는 Mock
    public static func failing() -> Self {
        return WCSessionClient(
            messages: { .finished },
            send: { _ in
                throw WCSessionError.notReachable
            },
            updateContext: { _ in
                throw WCSessionError.notActivated
            },
            receivedContext: { nil },
            isReachable: { false },
            isActivated: { false },
            activate: {}
        )
    }
}

// MARK: - WCSessionError (Platform-agnostic)
#if !os(iOS) && !os(watchOS)
public enum WCSessionError: Error, LocalizedError {
    case notSupported
    case notActivated
    case notReachable
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "WCSession is not supported on this device"
        case .notActivated:
            return "WCSession is not activated"
        case .notReachable:
            return "Counterpart device is not reachable"
        case .encodingFailed:
            return "Failed to encode message"
        case .decodingFailed:
            return "Failed to decode message"
        }
    }
}
#endif
