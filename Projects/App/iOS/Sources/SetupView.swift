import SwiftUI
import ComposableArchitecture
import SharedDomain

public struct SetupView: View {
    let store: StoreOf<SetupFeature>

    public init(store: StoreOf<SetupFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        heroCard

                        wakeTimeCard
                        windowCard
                        sensitivityCard
                        activeCard
                        syncCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("알람 설정")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { store.send(.onAppear) }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good Morning, Gabbun")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d:%02d", store.wakeTimeHour, store.wakeTimeMinute))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("기상 목표")
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text("스마트 윈도우 \(store.windowMinutes)분 · 민감도 \(sensitivityText(store.sensitivity))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.55), Color.indigo.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var wakeTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("기상 시간")
                .font(.headline)

            HStack {
                Text("목표 기상 시간")
                Spacer()
                Picker("시", selection: Binding(
                    get: { store.wakeTimeHour },
                    set: { store.send(.wakeTimeHourChanged($0)) }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)

                Text(":")

                Picker("분", selection: Binding(
                    get: { store.wakeTimeMinute },
                    set: { store.send(.wakeTimeMinuteChanged($0)) }
                )) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)
            }
        }
        .glassCard()
    }

    private var windowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("알람 윈도우")
                .font(.headline)

            Picker("알람 윈도우", selection: Binding(
                get: { store.windowMinutes },
                set: { store.send(.windowMinutesChanged($0)) }
            )) {
                Text("15분").tag(15)
                Text("30분").tag(30)
                Text("45분").tag(45)
            }
            .pickerStyle(.segmented)

            Text("목표 시간 전 최적 기상 시점을 찾는 탐색 범위")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var sensitivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("민감도")
                .font(.headline)

            Picker("민감도", selection: Binding(
                get: { store.sensitivity },
                set: { store.send(.sensitivityChanged($0)) }
            )) {
                Text("보수적").tag(AlarmSchedule.Sensitivity.conservative)
                Text("균형").tag(AlarmSchedule.Sensitivity.balanced)
                Text("민감").tag(AlarmSchedule.Sensitivity.sensitive)
            }
            .pickerStyle(.segmented)

            Text("보수적: 오탐 최소화 · 균형: 기본 추천 · 민감: 빠른 반응")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("알람 활성화", isOn: Binding(
                get: { store.enabled },
                set: { _ in store.send(.enabledToggled) }
            ))
            .fontWeight(.semibold)

            Text(store.enabled ? "활성화 상태입니다." : "비활성화 상태입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.send(.syncButtonTapped)
            } label: {
                HStack {
                    if store.isSyncing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(store.isSyncing ? "동기화 중..." : "Watch로 동기화")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .disabled(!store.isActivated || store.isSyncing)
            .opacity((!store.isActivated || store.isSyncing) ? 0.5 : 1)

            Button {
                store.send(.testAlarmButtonTapped)
            } label: {
                Text("실기기 테스트 알람 (약 2분 후)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(!store.isActivated || store.isSyncing)
            .opacity((!store.isActivated || store.isSyncing) ? 0.5 : 1)

            HStack(spacing: 6) {
                Circle()
                    .fill(store.isReachable ? Color.green : store.isActivated ? Color.orange : Color.red)
                    .frame(width: 8, height: 8)
                Text(store.isReachable ? "Watch 활성" : store.isActivated ? "Watch 연결됨" : "Watch 연결 안 됨")
                    .font(.caption)
                    .foregroundStyle(store.isReachable ? .green : store.isActivated ? .orange : .red)
            }

            if let lastSyncAt = store.lastSyncAt {
                Text("마지막 동기화: \(formatDate(lastSyncAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .glassCard()
    }

    private func sensitivityText(_ sensitivity: AlarmSchedule.Sensitivity) -> String {
        switch sensitivity {
        case .conservative: return "보수적"
        case .balanced: return "균형"
        case .sensitive: return "민감"
        }
    }

    private static let syncDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale.current
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        let f = Self.syncDateFormatter
        f.timeZone = TimeZone.current
        return f.string(from: date)
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
