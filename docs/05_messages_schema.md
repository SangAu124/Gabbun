# 05. docs/05_messages_schema.md

## 1. 통신 원칙
* **No Raw Data**: 원시 센서 데이터는 전송하지 않음. 요약 및 이벤트만 전송.
* **Codable Payload**: 모든 메시지는 JSON 또는 Codable 형태로 직렬화.
* **Versioning**: 스키마 변경에 대비해 버전을 명시.

---

## 2. Envelope 구조 (공통)
```swift
struct Envelope<T: Codable>: Codable {
    let schemaVersion: Int   // 예: 1
    let messageId: UUID      // 고유 식별자
    let sentAt: Date         // 발송 시각
    let type: MessageType    // 메시지 타입 (enum string)
    let payload: T           // 실제 데이터
}
```

---

## 3. iPhone → Watch 메시지

### A. UpdateSchedule (`update_schedule`)
알람 설정을 워치에 업데이트합니다.
* **payload**:
  * `schedule`: `AlarmSchedule` 객체
    * `wakeTimeLocal`: "07:30" (또는 DateComponents)
    * `windowMinutes`: Int (e.g., 30)
    * `sensitivity`: Enum ("balanced", "sensitive"...)
    * `enabled`: Bool
  * `effectiveDate`: "YYYY-MM-DD" (적용 날짜, 오늘 or 내일)

### B. CancelSchedule (`cancel_schedule`)
설정된 알람을 취소합니다.
* **payload**:
  * `effectiveDate`: "YYYY-MM-DD"

---

## 4. Watch → iPhone 메시지

### A. AlarmFiredEvent (`alarm_fired`) - **핵심**
알람이 실제로 울렸을 때 즉시 전송합니다.
* **payload**:
  * `targetWakeAt`: 목표 기상 시각
  * `firedAt`: 실제 발화 시각
  * `reason`: "SMART" | "FORCED"
  * `scoreAtFire`: 발화 시점 점수 (Double)
  * `components`: `WakeabilityComponents` (모션/심박 요약)
  * `cooldownApplied`: Bool (쿨다운 적용 여부)

### B. SessionSummary (`session_summary`)
세션 종료(사용자가 알람 끔) 후 전체 요약.
* **payload**: `WakeSessionSummary`
  * `windowStartAt`, `windowEndAt`
  * `firedAt`, `reason`, `scoreAtFire`
  * `bestCandidateAt`, `bestScore` (윈도우 내 최고점 시점, 선택사항)
  * `batteryImpactEstimate`: Int? (%, 선택사항)

### C. Error (`error`)
오류 발생 시 보고용.
* **payload**:
  * `code`: String (예: "HK_AUTH_DENIED", "SESSION_FACTOR_FAILED")
  * `detail`: String (디버깅용 상세 메시지)

### D. SessionState (`session_state`) - 선택사항
UI 동기화용 상태값 (빈도 낮게 전송)
* **payload**:
  * `state`: "armed" | "monitoring" | "alarmFired" | "completed"
  * `lastScore`: Double?

---

## 5. 스키마 버전 전략
* **schemaVersion**: 초기값 **1**
* 모델 변경 시:
    * 이전 버전과 호환 불가한 필드 삭제/변경 시 버전 업 (`2`)
    * 필드 추가는 `Optional`로 처리하여 하위 호환 유지 권장