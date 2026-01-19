import SwiftUI
import SharedDomain
import SharedAlgorithm
import SharedTransport

@main
struct GabbunApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Gabbun")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Smart Wake Alarm")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("iOS App")
                .font(.caption)
                .foregroundColor(.gray)

            // 빌드 확인용 플레이스홀더
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Modules Linked:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("✓ SharedDomain")
                Text("✓ SharedAlgorithm")
                Text("✓ SharedTransport")
            }
            .font(.caption)
            .foregroundColor(.green)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
