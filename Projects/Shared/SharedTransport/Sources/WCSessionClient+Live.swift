import Foundation
import ComposableArchitecture
#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

// MARK: - Live Implementation
extension WCSessionClient {
    public static func live() -> Self {
        #if os(iOS) || os(watchOS)
        return LiveWCSessionClient.shared.client()
        #else
        // 다른 플랫폼에서는 동작하지 않음
        return WCSessionClient()
        #endif
    }
}

#if os(iOS) || os(watchOS)
// MARK: - LiveWCSessionClient (Internal)
// WCSession의 델리게이트를 처리하고 메시지를 스트리밍
private final class LiveWCSessionClient: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = LiveWCSessionClient()

    private let session: WCSession
    private let messagesContinuation: AsyncStream<TransportMessage>.Continuation
    private let messagesStream: AsyncStream<TransportMessage>

    private override init() {
        self.session = WCSession.default

        var continuation: AsyncStream<TransportMessage>.Continuation!
        let stream = AsyncStream<TransportMessage> { continuation = $0 }
        self.messagesContinuation = continuation
        self.messagesStream = stream

        super.init()

        // Delegate 설정 및 활성화는 명시적으로 activate() 호출 시 수행
    }

    func client() -> WCSessionClient {
        return WCSessionClient(
            messages: { [weak self] in
                guard let self = self else { return .finished }
                return self.messagesStream
            },
            send: { [weak self] message in
                try await self?.send(message: message)
            },
            updateContext: { [weak self] message in
                try self?.updateApplicationContext(message: message)
            },
            receivedContext: { [weak self] in
                self?.getReceivedApplicationContext()
            },
            isReachable: { [weak self] in
                self?.session.isReachable ?? false
            },
            isActivated: { [weak self] in
                guard let self = self else { return false }
                #if os(iOS)
                return self.session.activationState == .activated
                    && self.session.isPaired
                    && self.session.isWatchAppInstalled
                #elseif os(watchOS)
                return self.session.activationState == .activated
                    && self.session.isCompanionAppInstalled
                #else
                return false
                #endif
            },
            activate: { [weak self] in
                await self?.activate()
            }
        )
    }

    private func activate() async {
        guard WCSession.isSupported() else { return }

        if session.delegate == nil {
            session.delegate = self
        }

        if session.activationState != .activated {
            session.activate()
        }
    }

    private func send(message: TransportMessage) async throws {
        guard session.activationState == .activated else {
            throw WCSessionError.notActivated
        }

        guard session.isReachable else {
            throw WCSessionError.notReachable
        }

        let dict = message.toDictionary()

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(dict, replyHandler: { _ in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    private func updateApplicationContext(message: TransportMessage) throws {
        guard session.activationState == .activated else {
            throw WCSessionError.notActivated
        }

        let dict = message.toDictionary()
        try session.updateApplicationContext(dict)
    }

    private func getReceivedApplicationContext() -> TransportMessage? {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return nil }
        return TransportMessage.fromDictionary(context)
    }

    // MARK: - WCSessionDelegate
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // 활성화 완료 로그 (필요시 처리)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS 전용: 비활성화 처리
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS 전용: 재활성화 필요
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let transportMessage = TransportMessage.fromDictionary(message) else {
            return
        }
        messagesContinuation.yield(transportMessage)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let transportMessage = TransportMessage.fromDictionary(message) else {
            replyHandler([:])
            return
        }
        messagesContinuation.yield(transportMessage)
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let transportMessage = TransportMessage.fromDictionary(applicationContext) else {
            return
        }
        messagesContinuation.yield(transportMessage)
    }
}

// MARK: - WCSessionError
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
