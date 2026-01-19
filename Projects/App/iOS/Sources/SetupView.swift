import SwiftUI
import ComposableArchitecture
import SharedDomain

// MARK: - SetupView
public struct SetupView: View {
    let store: StoreOf<SetupFeature>

    public init(store: StoreOf<SetupFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - 기상 시간 설정
                Section {
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
                } header: {
                    Text("기상 시간")
                }

                // MARK: - 윈도우 설정
                Section {
                    Picker("알람 윈도우", selection: Binding(
                        get: { store.windowMinutes },
                        set: { store.send(.windowMinutesChanged($0)) }
                    )) {
                        Text("15분").tag(15)
                        Text("30분").tag(30)
                        Text("45분").tag(45)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("알람 윈도우")
                } footer: {
                    Text("목표 시간 전 몇 분부터 최적의 기상 시점을 찾을지 설정합니다.")
                }

                // MARK: - 민감도 설정
                Section {
                    Picker("민감도", selection: Binding(
                        get: { store.sensitivity },
                        set: { store.send(.sensitivityChanged($0)) }
                    )) {
                        Text("보수적").tag(AlarmSchedule.Sensitivity.conservative)
                        Text("균형").tag(AlarmSchedule.Sensitivity.balanced)
                        Text("민감").tag(AlarmSchedule.Sensitivity.sensitive)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("민감도")
                } footer: {
                    Text("보수적: 확실히 깬 상태일 때만 알람\n균형: 적당한 각성 상태에서 알람\n민감: 약간의 움직임에도 빠르게 반응")
                }

                // MARK: - 활성화 토글
                Section {
                    Toggle("알람 활성화", isOn: Binding(
                        get: { store.enabled },
                        set: { _ in store.send(.enabledToggled) }
                    ))
                } footer: {
                    Text("비활성화 시 알람이 울리지 않습니다.")
                }

                // MARK: - 동기화 버튼
                Section {
                    Button {
                        store.send(.syncButtonTapped)
                    } label: {
                        HStack {
                            if store.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(store.isSyncing ? "동기화 중..." : "Watch로 동기화")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!store.isReachable || store.isSyncing)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        // 연결 상태
                        HStack(spacing: 4) {
                            Circle()
                                .fill(store.isReachable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(store.isReachable ? "Watch 연결됨" : "Watch 연결 안 됨")
                                .font(.caption)
                                .foregroundColor(store.isReachable ? .green : .red)
                        }

                        // 마지막 동기화 시간
                        if let lastSyncAt = store.lastSyncAt {
                            Text("마지막 동기화: \(formatDate(lastSyncAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 오류 메시지
                        if let errorMessage = store.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("알람 설정")
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
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
