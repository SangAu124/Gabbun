import SwiftUI
import ComposableArchitecture
import SharedDomain
import SharedAlgorithm
import SharedTransport

@main
struct GabbunWatchApp: App {
    let store: StoreOf<WatchAppFeature>

    init() {
        self.store = Store(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.wcSessionClient = .liveValue
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchArmingView(store: store.scope(state: \.arming, action: \.arming))
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }
}

#Preview {
    WatchArmingView(
        store: Store(initialState: WatchArmingFeature.State()) {
            WatchArmingFeature()
        }
    )
}
