# 03. docs/03_algorithm_spec.md

## 1. 핵심 알고리즘 목표
“얕은 수면”을 직접 판별하지 않고, 각성 직전/각성 근접을 나타내는 신호(움직임 증가 + 심박 패턴 변화)를 이용해 **Wakeability(기상 적합도)**를 계산하고 트리거한다.

---

## 2. 상태 머신 (State Machine)

### A. 상태 정의
1. **Idle**: 기능 꺼짐 / 미설정
2. **Armed**: 목표 기상 시각 설정 완료, 윈도우 시작까지 대기
3. **Monitoring**: 스마트 윈도우 진입, 고정밀 센서 분석 시작
4. **AlarmFired**: 알람 발화 (사용자 인터랙션 대기)
5. **Completed**: 성공/실패(강제 알람 포함) 종료 및 요약 저장

### B. 전이 조건 (Transitions)
* **Armed → Monitoring**
  * `now >= wakeTime - windowMinutes`
* **Monitoring → AlarmFired (Smart)**
  * `wakeability_score >= threshold` **AND** `majority_condition_met` **AND** `cooldown_passed`
* **Monitoring → AlarmFired (Forced)**
  * `now >= wakeTime`
* **AlarmFired → Completed**
  * 사용자 종료(Dismiss) 또는 타임아웃

---

## 3. 입력 신호 및 Feature Engineering

### A. 입력 신호 (Source)
* **Motion**: 가속도 크기 `|a|` (Core Motion, 워치 센서)
* **Heart Rate**: BPM (HealthKit 실시간 스트림)

### B. Feature 정의 (갱신 주기: 30~60초)

#### Motion Features (최근 60초 창)
* **motion_std**: `|a|`의 표준편차 (움직임의 격렬함)
* **motion_peaks**: 임계값 초과 피크 수 (뒤척임/자세변화 근사)
* **motion_energy**: `Σ |a|^2` (간단 에너지 지표)

#### HR Features (최근 120초 창)
* **hr_mean**: 평균 HR
* **hr_slope**: 선형 회귀 기울기 또는 (최근 30초 평균 - 이전 90초 평균)
* **hr_var**: 표준편차 (짧은 창 변동성)

---

## 4. Wakeability Score 산출

### A. 정규화 및 결합
Feature 값을 0~1 사이로 정규화한 뒤 가중치 합산:

```
m = normalize(motion_std + α * motion_peaks + β * motion_energy)
h = normalize(γ * hr_slope + δ * hr_var)
still = normalize(stillness_penalty) 

// 예: 최근 3분간 motion이 매우 낮으면 패널티 부여 (깊은 잠 회피)
score = w_m * m + w_h * h - w_s * still
```

### B. 권장 가중치 방향
* `w_m > w_h`: 모션이 가장 확실한 각성 신호임.
* 단, 사용자가 "잘 안 움직이는 타입"이면 개인화 옵션으로 `w_h` 상향 가능.

---

## 5. 트리거 로직 (Trigger Logic)

1. **Score Check**: `score >= threshold` (기본 0.72)
2. **Min Interval**: `cooldown` (5분) 내 재발화 금지
3. **Persistency**: **최근 3개 샘플 중 2개 이상** 점수 초과 시 발화
4. **Forced Fire**: 윈도우 종료(목표 기상) 시각 도달 시 무조건 발화

---

## 6. 출력 데이터 (요약)
워치에서 iPhone으로 전송하는 **최소 데이터** (원시 데이터 금지)

* `wakeTimeTarget`: 목표 기상 시각
* `windowStart`, `windowEnd`: 윈도우 구간
* `firedAt`: 실제 알람 발화 시각
* `firedReason`: `SMART_SCORE` 또는 `FORCED_TIME`
* `scoreAtFire`: 발화 시점의 점수
* `componentsAtFire`: 모션/심박 Feature 요약값
