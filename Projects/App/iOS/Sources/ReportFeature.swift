import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport

// MARK: - ReportFeature
@Reducer
public struct ReportFeature {
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var sessions: [WakeSessionSummary] = []

        public init() {}
    }

    // MARK: - Action
    public enum Action: Sendable {
        case onAppear
        case sessionsLoaded([WakeSessionSummary])
        case sessionReceived(WakeSessionSummary)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.sessionStoreClient) var sessionStoreClient

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // 영속 저장소에서 로드
                    let saved = (try? sessionStoreClient.load()) ?? []

                    // 마지막으로 수신된 context에서 sessionSummary 파싱 (미처리 세션 추가)
                    if let context = wcSessionClient.receivedContext(),
                       let envelope: Envelope<SessionSummaryPayload> = try? context.decode(),
                       envelope.type == .sessionSummary {
                        let incoming = envelope.payload.summary
                        // sessionReceived와 동일 기준(firedAt + reason)으로 중복 검사
                        let isDuplicate = saved.contains {
                            $0.firedAt == incoming.firedAt && $0.reason == incoming.reason
                        }
                        let merged = isDuplicate ? saved : [incoming] + saved
                        await send(.sessionsLoaded(merged))
                    } else {
                        await send(.sessionsLoaded(saved))
                    }
                }

            case let .sessionsLoaded(sessions):
                state.sessions = sessions
                return .none

            case let .sessionReceived(summary):
                // firedAt + reason 기준으로 중복 검사 (Equatable 전체 비교보다 명시적)
                let isDuplicate = state.sessions.contains {
                    $0.firedAt == summary.firedAt && $0.reason == summary.reason
                }
                guard !isDuplicate else { return .none }
                state.sessions.insert(summary, at: 0)
                let sessions = state.sessions
                return .run { _ in
                    do {
                        try sessionStoreClient.save(sessions)
                    } catch {
                        print("[ReportFeature] 세션 저장 실패: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
