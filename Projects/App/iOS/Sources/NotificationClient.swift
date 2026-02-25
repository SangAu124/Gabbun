import Foundation
import UserNotifications
import ComposableArchitecture

// MARK: - NotificationClient

@DependencyClient
public struct NotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async -> Bool = { false }
    public var scheduleWakeUpFallback: @Sendable (_ wakeTime: Date) async -> Void = { _ in }
    public var cancelWakeUpFallback: @Sendable () async -> Void = { }
}

// MARK: - DependencyKey

extension NotificationClient: DependencyKey {
    // 폴백 알림 고정 식별자 (cancel 시 사용)
    private static let fallbackIdentifier = "gabbun.wakeup.fallback"

    public static let liveValue = NotificationClient(
        requestAuthorization: {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            return granted ?? false
        },
        scheduleWakeUpFallback: { wakeTime in
            let center = UNUserNotificationCenter.current()

            // 기존 폴백 알림 제거
            center.removePendingNotificationRequests(withIdentifiers: [fallbackIdentifier])

            // 콘텐츠 구성
            let content = UNMutableNotificationContent()
            content.title = "가뿐 - 기상 시각"
            content.body = "워치 알람을 확인해주세요."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            // 기상 시각 기준 트리거
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: wakeTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: fallbackIdentifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("[NotificationClient] 폴백 알림 스케줄 실패: \(error.localizedDescription)")
            }
        },
        cancelWakeUpFallback: {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [fallbackIdentifier])
        }
    )

    public static let testValue = NotificationClient()
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
