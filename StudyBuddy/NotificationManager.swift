import Foundation
import UserNotifications

// MARK: - 로컬 알림 관리 싱글턴
// 원격 푸시 없이 UNUserNotificationCenter만 사용
// "다음 결제일 하나만 예약, 앱 열릴 때마다 재계산" 방식으로 운영
@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        // 델리게이트 등록 — 앱 포그라운드에서도 배너 표시 가능
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - 권한

    func requestPermission() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await updateStatus()
        } catch {
            print("알림 권한 요청 실패: \(error)")
        }
    }

    func updateStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - 예약

    /// 구독 하나의 알림 예약 (기존 알림은 먼저 취소 후 재예약)
    func schedule(for subscription: Subscription) {
        cancel(for: subscription)
        guard subscription.notifyEnabled else { return }

        let center = UNUserNotificationCenter.current()

        // 1. 결제 알림 — 다음 결제일 기준 notifyDaysBefore일 전 오전 9시
        let nextBilling = BillingCalculator.nextBillingDate(for: subscription)
        if let notifyDate = Calendar.current.date(
            byAdding: .day,
            value: -subscription.notifyDaysBefore,
            to: nextBilling
        ) {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: notifyDate)
            comps.hour = 9; comps.minute = 0

            // 이미 지난 시점이면 예약하지 않음
            if let fireDate = Calendar.current.date(from: comps), fireDate > .now {
                let content     = UNMutableNotificationContent()
                content.title   = "결제 예정 알림"
                let planPart    = subscription.planName.isEmpty ? "" : " \(subscription.planName)"
                content.body    = "\(subscription.notifyDaysBefore)일 뒤 \(subscription.name)\(planPart) \(subscription.fee.formatted())원이 결제돼요"
                content.sound   = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(subscription.id)-billing",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { error in
                    if let error { print("결제 알림 예약 실패: \(error)") }
                }
            }
        }

        // 2. 무료체험 알림 — 종료 하루 전 오전 9시
        if let trialEnd = subscription.trialEndDate,
           let notifyDate = Calendar.current.date(byAdding: .day, value: -1, to: trialEnd) {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: notifyDate)
            comps.hour = 9; comps.minute = 0

            if let fireDate = Calendar.current.date(from: comps), fireDate > .now {
                let content   = UNMutableNotificationContent()
                content.title = "무료체험 종료 알림"
                content.body  = "내일 \(subscription.name) 무료체험이 끝나요. 해지하려면 오늘 하세요"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(subscription.id)-trial",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { error in
                    if let error { print("체험 알림 예약 실패: \(error)") }
                }
            }
        }
    }

    /// 구독의 모든 알림 취소 (식별자 패턴: "UUID-billing", "UUID-trial")
    func cancel(for subscription: Subscription) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: ["\(subscription.id)-billing", "\(subscription.id)-trial"]
            )
    }

    /// 전체 알림 삭제 후 재예약
    /// 매월 반복 예약 대신 "다음 결제일 하나만 등록"하고 앱을 열 때마다 이 함수를 호출
    func rescheduleAll(_ subscriptions: [Subscription]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for sub in subscriptions { schedule(for: sub) }
    }

    /// 10초 뒤 테스트 알림 (알림이 실제로 도착하는지 확인용)
    func sendTestNotification() {
        let content   = UNMutableNotificationContent()
        content.title = "테스트 알림"
        content.body  = "알림이 정상적으로 동작하고 있어요 ✓"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("테스트 알림 실패: \(error)") }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 앱이 켜진 상태에서도 배너·소리로 표시
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
