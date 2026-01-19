# 07. docs/07_mvp_checklist.md

## 1. MVP 완료 정의 (Success Criteria)
* **iOS 설정 → Watch 동기화**: 대기 중인 워치 앱에 `AlarmSchedule` 전달 성공
* **알람 발화**:
    * **Smart Trigger**: 윈도우 내 점수 만족 시 발화
    * **Forced Trigger**: 윈도우 내 미발화 시 목표 시각에 발화
* **결과 리포트**: 알람 종료 후 iOS 앱에서 `AlarmFiredEvent` 내용 확인 가능

---

## 2. 구현 우선순위 (Implementation Priorities)

### Phase 1: 기반 구축
* [ ] **Shared Modules (SPM)**
    * `SharedDomain`: `AlarmSchedule`, `WakeabilityComponents`, `WakeSessionSummary`
    * `SharedTransport`: `Envelope` Codable, Message Types
* [ ] **Project Setup**: Tuist Workspace (iOS + Watch + Shared)

### Phase 2: 연결 및 설정 (iOS -> Watch)
* [ ] **iOS SetupFeature**: 설정 UI 및 WCSession 전송
* [ ] **Watch ArmingFeature**: WCSession 수신 및 `AlarmSchedule` 저장/표시

### Phase 3: 핵심 로직 (Watch Monitoring)
* [ ] **Sensor Clients**: CoreMotion(25Hz), HKWorkoutSession(HeartRate) 연동
* [ ] **SharedAlgorithm**: 점수 계산 및 상태 머신 유닛 테스트
* [ ] **Watch MonitoringFeature**:
    * 윈도우 진입 시 센서 시작
    * 실시간 Feature/Score 계산
    * Trigger(`Smart` or `Forced`) 로직 연결

### Phase 4: 알람 및 리포트 (Watch -> iOS)
* [ ] **Watch AlarmFeature**: 햅틱/사운드 재생, 종료 버튼
* [ ] **Reporting**: 알람 종료 시 `SessionSummary` 생성 및 WCSession 전송
* [ ] **iOS SessionHistoryFeature**: 수신된 요약 데이터 저장 및 리스트 표시

---

## 3. 수동 테스트 시나리오
* **케이스 A (성공)**: 윈도우 내 흔들어서 점수 임계값 초과 → 5분 내 Smart 알람 발화
* **케이스 B (강제)**: 윈도우 내 가만히 있기 → 목표 시각 정각에 Forced 알람 발화
* **케이스 C (연결)**: 폰 없이 워치 단독 알람 울림 → 나중에 폰 연결 시 로그 동기화 확인

---

## 4. 바로 개발 가능한 기본값 세트 (Balanced Preset)
> **Window 30m / Motion 25Hz / Feature 30s / Threshold 0.72 / Majority 2 of 3 / Cooldown 5m**
