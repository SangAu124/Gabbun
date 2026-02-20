import SwiftUI
import ComposableArchitecture
import SharedDomain

// MARK: - ReportView
struct ReportView: View {
    let store: StoreOf<ReportFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "기록 없음",
                        systemImage: "moon.zzz",
                        description: Text("알람이 발화되면 여기에 기록이 표시됩니다.")
                    )
                } else {
                    List(store.sessions, id: \.firedAt) { session in
                        SessionRow(summary: session)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("수면 기록")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - SessionRow
private struct SessionRow: View {
    let summary: WakeSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.firedAt, style: .date)
                    .font(.headline)
                Spacer()
                TriggerBadge(reason: summary.reason)
            }

            HStack(spacing: 16) {
                LabeledValue(label: "발화 시각", value: summary.firedAt.formatted(date: .omitted, time: .shortened))
                LabeledValue(label: "점수", value: String(format: "%.0f%%", summary.scoreAtFire * 100))
            }

            HStack {
                Text("모니터링")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(summary.windowStartAt, style: .time)
                    .font(.caption)
                Text("~")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.windowEndAt, style: .time)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TriggerBadge
private struct TriggerBadge: View {
    let reason: WakeSessionSummary.FiredReason

    var body: some View {
        Text(reason == .smart ? "스마트" : "강제")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(reason == .smart ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(reason == .smart ? .green : .orange)
            .clipShape(Capsule())
    }
}

// MARK: - LabeledValue
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
        }
    }
}

// MARK: - Preview
#Preview {
    ReportView(
        store: Store(initialState: ReportFeature.State()) {
            ReportFeature()
        } withDependencies: {
            $0.wcSessionClient = .previewValue
        }
    )
}
