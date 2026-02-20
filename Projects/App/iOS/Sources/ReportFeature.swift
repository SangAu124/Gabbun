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
        case sessionReceived(WakeSessionSummary)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 마지막으로 수신된 context에서 sessionSummary 파싱
                if let context = wcSessionClient.receivedContext(),
                   let envelope: Envelope<SessionSummaryPayload> = try? context.decode(),
                   envelope.type == .sessionSummary {
                    let summary = envelope.payload.summary
                    if !state.sessions.contains(summary) {
                        state.sessions.insert(summary, at: 0)
                    }
                }
                return .none

            case let .sessionReceived(summary):
                if !state.sessions.contains(summary) {
                    state.sessions.insert(summary, at: 0)
                }
                return .none
            }
        }
    }
}
