import SwiftUI
import ComposableArchitecture
import SharedDomain

struct ReportView: View {
    let store: StoreOf<ReportFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "기록 없음",
                        systemImage: "moon.zzz",
                        description: Text("알람이 발화되면 여기에 기록이 표시됩니다.")
                    )
                    .foregroundStyle(.white.opacity(0.85))
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            summaryCard

                            ForEach(store.sessions, id: \.firedAt) { session in
                                SessionRow(summary: session)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("수면 기록")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { store.send(.onAppear) }
    }

    private var summaryCard: some View {
        let smartCount = store.sessions.filter { $0.reason == .smart }.count
        let total = store.sessions.count
        let smartRate = total == 0 ? 0 : Int((Double(smartCount) / Double(total) * 100).rounded())

        return HStack {
            statItem(title: "총 기록", value: "\(total)회")
            Divider().overlay(Color.white.opacity(0.2))
            statItem(title: "스마트 기상", value: "\(smartRate)%")
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.55), Color.purple.opacity(0.45)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionRow: View {
    let summary: WakeSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.firedAt, format: .dateTime.month().day().weekday())
                        .font(.headline)
                    Text(summary.firedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TriggerBadge(reason: summary.reason)
            }

            HStack(spacing: 16) {
                LabeledValue(label: "점수", value: String(format: "%.0f%%", summary.scoreAtFire * 100))
                LabeledValue(label: "모니터링", value: "\(summary.windowStartAt.formatted(date: .omitted, time: .shortened)) ~ \(summary.windowEndAt.formatted(date: .omitted, time: .shortened))")
            }
        }
        .glassCard()
    }
}

private struct TriggerBadge: View {
    let reason: WakeSessionSummary.FiredReason

    var body: some View {
        Text(reason == .smart ? "스마트" : "강제")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(reason == .smart ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
            .foregroundStyle(reason == .smart ? .green : .orange)
            .clipShape(Capsule())
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

#Preview {
    ReportView(
        store: Store(initialState: ReportFeature.State()) {
            ReportFeature()
        } withDependencies: {
            $0.wcSessionClient = .previewValue
        }
    )
}
