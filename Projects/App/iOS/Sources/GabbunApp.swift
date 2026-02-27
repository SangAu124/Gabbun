import SwiftUI
import ComposableArchitecture
import SharedDomain
import SharedAlgorithm
import SharedTransport

// MARK: - AppFeature (Root)
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var setup = SetupFeature.State()
        var report = ReportFeature.State()
    }

    enum Action: Sendable {
        case setup(SetupFeature.Action)
        case report(ReportFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.setup, action: \.setup) {
            SetupFeature()
        }
        Scope(state: \.report, action: \.report) {
            ReportFeature()
        }
        Reduce { state, action in
            switch action {
            // Setup에서 세션 요약 수신 시 Report에도 전달
            case let .setup(.sessionSummaryReceived(summary)):
                return .send(.report(.sessionReceived(summary)))
            case .setup, .report:
                return .none
            }
        }
    }
}

// MARK: - GabbunApp
@main
struct GabbunApp: App {
    let store: StoreOf<AppFeature>

    init() {
        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.wcSessionClient = .liveValue
            $0.notificationClient = .liveValue
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}

private struct RootTabView: View {
    let store: StoreOf<AppFeature>

    @State private var selectedTab: Int = ProcessInfo.processInfo.arguments.contains("-showReportFirst") ? 1 : 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SetupView(store: store.scope(state: \.setup, action: \.setup))
                .tabItem {
                    Label("알람 설정", systemImage: "alarm")
                }
                .tag(0)

            ReportView(store: store.scope(state: \.report, action: \.report))
                .tabItem {
                    Label("수면 기록", systemImage: "list.bullet.clipboard")
                }
                .tag(1)
        }
    }
}

#Preview {
    TabView {
        SetupView(
            store: Store(initialState: SetupFeature.State()) {
                SetupFeature()
            } withDependencies: {
                $0.wcSessionClient = .previewValue
                $0.notificationClient = .testValue
            }
        )
        .tabItem { Label("알람 설정", systemImage: "alarm") }

        ReportView(
            store: Store(initialState: ReportFeature.State()) {
                ReportFeature()
            } withDependencies: {
                $0.wcSessionClient = .previewValue
            }
        )
        .tabItem { Label("수면 기록", systemImage: "list.bullet.clipboard") }
    }
}
