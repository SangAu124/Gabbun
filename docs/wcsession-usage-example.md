# WCSessionClient 사용 예시

## 개요
WCSessionClient는 TCA Dependency로 설계된 WatchConnectivity 클라이언트입니다.
iOS와 watchOS 간 TransportMessage(Envelope 기반)를 송수신합니다.

## 특징
- AsyncStream 기반 메시지 수신
- Type-safe Envelope 패턴
- iOS/watchOS 조건부 컴파일 지원
- TCA Dependency 통합
- 테스트/프리뷰용 Mock 제공

---

## 1. iOS에서 updateSchedule 전송

```swift
import SwiftUI
import ComposableArchitecture
import SharedTransport
import SharedDomain

// MARK: - Feature Reducer
@Reducer
struct ScheduleSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var schedule: AlarmSchedule = AlarmSchedule(
            wakeTimeLocal: "07:00",
            windowMinutes: 30,
            sensitivity: .balanced,
            enabled: true
        )
        var isSending: Bool = false
        var lastSentDate: Date?
        var errorMessage: String?
    }

    enum Action {
        case sendScheduleButtonTapped
        case sendScheduleResponse(Result<Void, Error>)
        case wcSessionActivated
        case receivedMessage(TransportMessage)
    }

    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sendScheduleButtonTapped:
                state.isSending = true
                state.errorMessage = nil

                let schedule = state.schedule
                let effectiveDate = formatDate(now)

                return .run { send in
                    do {
                        // 1. Envelope 생성
                        let payload = UpdateSchedulePayload(
                            schedule: schedule,
                            effectiveDate: effectiveDate
                        )
                        let envelope = Envelope(
                            type: .updateSchedule,
                            payload: payload
                        )

                        // 2. TransportMessage로 변환
                        let message = try TransportMessage(envelope: envelope)

                        // 3. 전송
                        try await wcSessionClient.send(message)

                        await send(.sendScheduleResponse(.success(())))
                    } catch {
                        await send(.sendScheduleResponse(.failure(error)))
                    }
                }

            case .sendScheduleResponse(.success):
                state.isSending = false
                state.lastSentDate = now
                return .none

            case .sendScheduleResponse(.failure(let error)):
                state.isSending = false
                state.errorMessage = error.localizedDescription
                return .none

            case .wcSessionActivated:
                return .none

            case .receivedMessage(let message):
                // Watch로부터 응답 수신 처리 (옵션)
                return .none
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - View
struct ScheduleSettingsView: View {
    let store: StoreOf<ScheduleSettingsFeature>

    var body: some View {
        Form {
            Section("알람 설정") {
                // ... 설정 UI ...
            }

            Section {
                Button {
                    store.send(.sendScheduleButtonTapped)
                } label: {
                    if store.isSending {
                        HStack {
                            ProgressView()
                            Text("전송 중...")
                        }
                    } else {
                        Text("Watch로 전송")
                    }
                }
                .disabled(store.isSending)

                if let lastSent = store.lastSentDate {
                    Text("마지막 전송: \(lastSent, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = store.errorMessage {
                    Text("오류: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("알람 스케줄")
    }
}
```

---

## 2. watchOS에서 메시지 수신 및 처리

```swift
import SwiftUI
import ComposableArchitecture
import SharedTransport
import SharedDomain

// MARK: - Feature Reducer
@Reducer
struct WatchAlarmFeature {
    @ObservableState
    struct State: Equatable {
        var currentSchedule: AlarmSchedule?
        var effectiveDate: String?
        var lastReceivedAt: Date?
        var isReachable: Bool = false
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case wcSessionActivated
        case receivedMessage(TransportMessage)
        case reachabilityChanged(Bool)
        case sendAcknowledgment
    }

    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // 1. WCSession 활성화
                    await wcSessionClient.activate()
                    await send(.wcSessionActivated)

                    // 2. 메시지 스트림 구독
                    for await message in wcSessionClient.messages() {
                        await send(.receivedMessage(message))
                    }
                }

            case .wcSessionActivated:
                state.isReachable = wcSessionClient.isReachable()
                return .none

            case .receivedMessage(let message):
                state.lastReceivedAt = now

                // 메시지 타입 추출을 위해 우선 타입만 확인
                do {
                    // MessageType에 따라 분기
                    if let envelope = try? message.decode() as Envelope<UpdateSchedulePayload> {
                        return handleUpdateSchedule(state: &state, envelope: envelope)
                    } else if let envelope = try? message.decode() as Envelope<PingPayload> {
                        return handlePing(state: &state, envelope: envelope)
                    }
                    // 다른 메시지 타입 처리...
                } catch {
                    state.errorMessage = "메시지 파싱 실패: \(error.localizedDescription)"
                }

                return .none

            case .reachabilityChanged(let isReachable):
                state.isReachable = isReachable
                return .none

            case .sendAcknowledgment:
                // Acknowledgment 전송 (옵션)
                return .none
            }
        }
    }

    private func handleUpdateSchedule(
        state: inout State,
        envelope: Envelope<UpdateSchedulePayload>
    ) -> Effect<Action> {
        let payload = envelope.payload
        state.currentSchedule = payload.schedule
        state.effectiveDate = payload.effectiveDate

        print("[Watch] 새로운 스케줄 수신:")
        print("  - 기상 시각: \(payload.schedule.wakeTimeLocal)")
        print("  - 윈도우: \(payload.schedule.windowMinutes)분")
        print("  - 민감도: \(payload.schedule.sensitivity)")
        print("  - 활성화: \(payload.schedule.enabled)")
        print("  - 적용일: \(payload.effectiveDate)")

        // TODO: SharedAlgorithm에 스케줄 적용
        // TODO: 로컬 알람 등록

        return .send(.sendAcknowledgment)
    }

    private func handlePing(
        state: inout State,
        envelope: Envelope<PingPayload>
    ) -> Effect<Action> {
        print("[Watch] Ping 수신: \(envelope.payload.timestamp)")
        return .none
    }
}

// MARK: - View
struct WatchAlarmView: View {
    let store: StoreOf<WatchAlarmFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Gabbun Watch")
                    .font(.headline)

                Divider()

                if let schedule = store.currentSchedule {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재 스케줄")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("기상: \(schedule.wakeTimeLocal)")
                            .font(.body)
                        Text("윈도우: \(schedule.windowMinutes)분")
                            .font(.caption)
                        Text("민감도: \(schedule.sensitivity.rawValue)")
                            .font(.caption)
                        Text(schedule.enabled ? "활성화됨" : "비활성화됨")
                            .font(.caption)
                            .foregroundColor(schedule.enabled ? .green : .red)

                        if let effectiveDate = store.effectiveDate {
                            Text("적용일: \(effectiveDate)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("스케줄 없음")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack {
                    Circle()
                        .fill(store.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(store.isReachable ? "연결됨" : "연결 안 됨")
                        .font(.caption2)
                }

                if let lastReceived = store.lastReceivedAt {
                    Text("마지막 수신: \(lastReceived, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
```

---

## 3. App Entry Point에서 WCSessionClient 설정

### iOS App

```swift
import SwiftUI
import ComposableArchitecture
import SharedTransport

@main
struct GabbunApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var scheduleSettings = ScheduleSettingsFeature.State()
    }

    enum Action {
        case scheduleSettings(ScheduleSettingsFeature.Action)
        case onAppear
    }

    @Dependency(\.wcSessionClient) var wcSessionClient

    var body: some ReducerOf<Self> {
        Scope(state: \.scheduleSettings, action: \.scheduleSettings) {
            ScheduleSettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                // WCSession 활성화
                return .run { _ in
                    await wcSessionClient.activate()
                }

            case .scheduleSettings:
                return .none
            }
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            ScheduleSettingsView(
                store: store.scope(
                    state: \.scheduleSettings,
                    action: \.scheduleSettings
                )
            )
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
```

### watchOS App

```swift
import SwiftUI
import ComposableArchitecture
import SharedTransport

@main
struct GabbunWatchApp: App {
    let store = Store(initialState: WatchAlarmFeature.State()) {
        WatchAlarmFeature()
    }

    var body: some Scene {
        WindowGroup {
            WatchAlarmView(store: store)
        }
    }
}
```

---

## 4. Dependency 등록 (Live 환경)

```swift
// iOS/watchOS 공통
import ComposableArchitecture
import SharedTransport

extension WCSessionClient: DependencyKey {
    public static var liveValue: WCSessionClient {
        return .live()
    }
}
```

---

## 5. 테스트 예시

```swift
import XCTest
import ComposableArchitecture
import SharedTransport
import SharedDomain

@MainActor
final class ScheduleSettingsFeatureTests: XCTestCase {
    func testSendSchedule_Success() async {
        let clock = TestClock()

        let store = TestStore(initialState: ScheduleSettingsFeature.State()) {
            ScheduleSettingsFeature()
        } withDependencies: {
            $0.wcSessionClient = .mock(isReachable: true, isActivated: true)
            $0.date.now = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        }

        await store.send(.sendScheduleButtonTapped) {
            $0.isSending = true
            $0.errorMessage = nil
        }

        await store.receive(.sendScheduleResponse(.success(()))) {
            $0.isSending = false
            $0.lastSentDate = Date(timeIntervalSince1970: 1704067200)
        }
    }

    func testSendSchedule_Failure_NotReachable() async {
        let store = TestStore(initialState: ScheduleSettingsFeature.State()) {
            ScheduleSettingsFeature()
        } withDependencies: {
            $0.wcSessionClient = .failing()
        }

        await store.send(.sendScheduleButtonTapped) {
            $0.isSending = true
            $0.errorMessage = nil
        }

        await store.receive(.sendScheduleResponse(.failure(WCSessionError.notReachable))) {
            $0.isSending = false
            $0.errorMessage = WCSessionError.notReachable.localizedDescription
        }
    }
}
```

---

## 6. 주요 제약 및 권장 사항

### 제약
1. **원시 센서 데이터 전송 금지**: 모션, 심박수 등 원시 데이터는 전송하지 않음
2. **요약 이벤트만 전송**: AlarmFiredEvent, SessionSummary 등 요약된 이벤트만 전송
3. **Reachability 체크**: 전송 전 `isReachable()` 확인 필요
4. **Background 제한**: watchOS는 백그라운드에서 WCSession 제한적 동작

### 권장 사항
1. **에러 처리**: 네트워크 상태, 기기 연결 상태에 따른 에러 처리 구현
2. **재시도 로직**: 전송 실패 시 재시도 로직 추가
3. **메시지 큐**: Reachable 상태가 아닐 때 메시지 큐잉 고려
4. **Forced 알람**: WCSession 실패와 무관하게 목표 시각 Forced 알람은 반드시 동작

---

## 7. 디버깅 팁

```swift
// WCSession 상태 확인
let client = WCSessionClient.live()
print("Is Activated: \(client.isActivated())")
print("Is Reachable: \(client.isReachable())")

// 메시지 수신 모니터링
Task {
    for await message in client.messages() {
        print("[DEBUG] Received message: \(message)")
    }
}
```
