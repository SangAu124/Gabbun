import SwiftUI
import ComposableArchitecture
import SharedDomain
import SharedAlgorithm
import SharedTransport

@main
struct GabbunApp: App {
    var body: some Scene {
        WindowGroup {
            SetupView(
                store: Store(
                    initialState: SetupFeature.State()
                ) {
                    SetupFeature()
                } withDependencies: {
                    $0.wcSessionClient = .liveValue
                }
            )
        }
    }
}

#Preview {
    SetupView(
        store: Store(
            initialState: SetupFeature.State()
        ) {
            SetupFeature()
        } withDependencies: {
            $0.wcSessionClient = .previewValue
        }
    )
}
