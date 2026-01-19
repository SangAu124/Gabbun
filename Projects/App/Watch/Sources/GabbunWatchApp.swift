import SwiftUI
import SharedDomain
import SharedAlgorithm
import SharedTransport

@main
struct GabbunWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Gabbun")
                .font(.headline)

            Text("Watch App")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Modules:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("✓ Domain")
                Text("✓ Algorithm")
                Text("✓ Transport")
            }
            .font(.caption2)
            .foregroundColor(.green)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
