# 04. docs/04_architecture_tca.md

## 1. 최상위 구조 (권장 모듈)

**공유 코드(도메인/알고리즘)**는 SPM 패키지로 분리하여 iOS와 watchOS가 함께 사용하고, 플랫폼별 UI/로직은 TCA Feature로 구성합니다.

### A. Shared (SPM Package)
* **SharedDomain**
    * `AlarmSchedule` (wakeTime, windowMinutes, sensitivity 등)
    * `WakeabilityScore` (score, components)
    * `WakeSessionSummary` (firedAt, reason, scoreAtFire 등)
* **SharedAlgorithm**
    * Feature 계산 로직 (모션/HR → feature)
    * 점수 산출 및 정규화
    * 트리거 상태 머신 관리 (majority, cooldown, forced fire)
* **SharedTransport**
    * WatchConnectivity 메시지 스키마 (`Envelope`, `Payload` Codable)
    * 버전 관리 및 프로토콜 정의

### B. iOS App Modules (TCA Features)
* **AppFeature**: 루트 네비게이션 및 탭 관리
* **SetupFeature**: 기상 시각/윈도우/민감도 설정 화면, Watch 동기화 로직
* **SessionHistoryFeature**: 지난 알람 결과 리스트, 세부 리포트 화면
* **DiagnosticsFeature** (Dev/Beta): 배터리 소모량, 연결 상태, 로그 확인

### C. watchOS App Modules (TCA Features)
* **WatchAppFeature**: 워치 앱 루트
* **WatchArmingFeature**: 대기/Armed 상태, 오늘의 알람 정보 및 카운트다운
* **WatchMonitoringFeature**: **(핵심)** 센서 수집 + 실시간 알고리즘 + 트리거 판단
* **WatchAlarmFeature**: 알람 발화 화면 (햅틱/사운드, 스누즈/종료 UI)
* **WatchDiagnosticsFeature** (Dev/Beta): 실시간 Score/Feature 값 노출 (릴리즈 시 숨김)

---

## 2. 의존성 (Dependencies) 레이어 설계

TCA의 `Dependency` 시스템을 활용하여 외부 시스템과 인터페이스합니다.

### A. Shared Dependencies
* **AlgorithmClient**: `SharedAlgorithm` 패키지를 래핑
    * `start(config)`, `stop()`
    * `ingest(motion)`, `ingest(hr)`
    * `onScoreUpdate` (Stream), `onTrigger` (Event)

### B. watchOS Dependencies
* **MotionClient**: CoreMotion (Accelerometer) 접근
* **HeartRateClient**: HealthKit (HKWorkoutSession 필수) 연동
* **AlarmClient**: 햅틱 피드백(WKHaptic), 사운드 재생, 로컬 알림 스케줄링
* **RuntimeClient**: WKExtendedRuntimeSession 또는 HKWorkoutSession 생명주기 제어
* **WCSessionClient**: iOS와의 메시지 송수신

### C. iOS Dependencies
* **WCSessionClient**: Watch와의 메시지 송수신
* **StorageClient**: 알람 이력 요약 저장 (CoreData / SQLite / FileSystem)
* **PersonalizationClient** (선택): 사용자 피드백 기반 튜닝 파라미터 관리

---

## 3. 핵심 데이터 흐름 (Data Flow)

1. **Setup**: iOS `SetupFeature` → (WCSession) → Watch `UpdateSchedule`
2. **Monitoring**: Watch `MotionClient`/`HeartRateClient` → `AlgorithmClient` (Score 계산)
3. **Trigger**: `AlgorithmClient` (Trigger Event) → Watch `AlarmFeature` (Sound/Haptic)
4. **Summary**: Watch `AlarmFeature` (종료 시) → `SharedDomain.Summary` → (WCSession) → iOS `SessionHistoryFeature`