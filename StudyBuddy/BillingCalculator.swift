import SwiftUI

// MARK: - 결제 상태 열거형

/// 구독의 결제 임박 상태를 3단계(오늘·내일·지남)로 나타냄
enum BillingStatus {
    case today          // 오늘 결제일   → 빨강
    case tomorrow       // 내일 결제일   → 주황
    case trialExpired   // 무료체험 종료 → 회색
    case normal         // 그 외        → 보조색

    /// 뱃지·텍스트에 사용할 색상
    var color: Color {
        switch self {
        case .today:        return .red
        case .tomorrow:     return .orange
        case .trialExpired: return Color(.systemGray)
        case .normal:       return Color(.secondaryLabel)
        }
    }

    /// 뱃지에 표시할 텍스트 (빈 문자열이면 뱃지를 표시하지 않음)
    var label: String {
        switch self {
        case .today:        return "오늘 결제"
        case .tomorrow:     return "내일 결제"
        case .trialExpired: return "무료체험 지남"
        case .normal:       return ""
        }
    }
}

// MARK: - 결제일 계산기

/// 구독의 다음 결제일과 D-Day를 계산하는 유틸리티
/// 모든 함수는 static — 인스턴스 생성 없이 BillingCalculator.xxx() 형태로 호출
enum BillingCalculator {

    // MARK: 공개 API

    /// 구독의 다음 결제일을 계산해 반환한다.
    ///
    /// 오늘이 결제일이면 오늘을 반환하고, 결제일이 그 달에 존재하지 않으면
    /// 그 달의 마지막 날로 처리한다.
    ///
    /// # 경계값 예시
    ///
    /// **1. 31일 결제 + 30일까지 있는 달 (11월)**
    /// ```
    /// billingDay = 31,  today = 2024-11-05
    /// → 11월 최대 일수 = 30  →  clampedDay = 30
    /// → 반환: 2024-11-30
    /// ```
    ///
    /// **2. 오늘이 결제일**
    /// ```
    /// billingDay = 18,  today = 2024-11-18
    /// → 이번 달 18일 = today  →  thisMonth >= today 조건 충족
    /// → 반환: 2024-11-18   /  daysUntil = 0  →  .today
    /// ```
    ///
    /// **3. 월간: 12월 → 1월 넘어가기**
    /// ```
    /// billingDay = 20,  today = 2024-12-25
    /// → 이번 달 20일(2024-12-20) < today  →  다음 달로
    /// → 반환: 2025-01-20
    /// ```
    ///
    /// **4. 연간: 12월 이후 → 내년**
    /// ```
    /// billingMonth = 11,  billingDay = 30,  today = 2024-12-01
    /// → 올해 11-30 < today  →  내년으로
    /// → 반환: 2025-11-30
    /// ```
    static func nextBillingDate(for subscription: Subscription, from today: Date = .now) -> Date {
        let calendar  = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)

        switch subscription.billingCycle {
        case .monthly:
            return nextMonthlyDate(day: subscription.billingDay,
                                   from: startOfToday,
                                   calendar: calendar)
        case .yearly:
            let month = subscription.billingMonth ?? 1
            return nextYearlyDate(month: month,
                                  day: subscription.billingDay,
                                  from: startOfToday,
                                  calendar: calendar)
        }
    }

    /// 오늘(today)로부터 목표 날짜(date)까지 남은 일수를 반환한다.
    /// 시간은 무시하고 날짜 단위로만 비교한다.
    /// - 오늘이면 0,  어제면 -1,  내일이면 1
    static func daysUntil(_ date: Date, from today: Date = .now) -> Int {
        let calendar     = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let startOfDate  = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfDate).day ?? 0
    }

    /// 구독의 현재 결제 상태(BillingStatus)를 반환한다.
    static func billingStatus(for subscription: Subscription, from today: Date = .now) -> BillingStatus {
        // 무료체험 종료일이 이미 지났으면 trialExpired
        if let trialEnd = subscription.trialEndDate,
           daysUntil(trialEnd, from: today) < 0 {
            return .trialExpired
        }

        let days = daysUntil(nextBillingDate(for: subscription, from: today), from: today)
        switch days {
        case 0:  return .today
        case 1:  return .tomorrow
        default: return .normal
        }
    }

    // MARK: 내부 헬퍼

    /// 매월 결제 기준 다음 결제일 계산
    private static func nextMonthlyDate(day: Int, from today: Date, calendar: Calendar) -> Date {
        let year  = calendar.component(.year,  from: today)
        let month = calendar.component(.month, from: today)

        // 이번 달 결제일이 오늘 이후이면 이번 달 반환
        if let thisMonth = clamped(year: year, month: month, day: day, calendar: calendar),
           thisMonth >= today {
            return thisMonth
        }

        // 이번 달 결제일이 지났으면 다음 달로 이동
        // date(byAdding: .month)로 연·월을 안전하게 계산 (12월 → 1월 처리 포함)
        let nextAnchor = calendar.date(byAdding: .month, value: 1, to: today) ?? today
        let ny = calendar.component(.year,  from: nextAnchor)
        let nm = calendar.component(.month, from: nextAnchor)
        return clamped(year: ny, month: nm, day: day, calendar: calendar) ?? today
    }

    /// 매년 결제 기준 다음 결제일 계산
    private static func nextYearlyDate(month: Int, day: Int, from today: Date, calendar: Calendar) -> Date {
        let currentYear = calendar.component(.year, from: today)

        // 올해 결제일이 오늘 이후이면 올해 반환
        if let thisYear = clamped(year: currentYear, month: month, day: day, calendar: calendar),
           thisYear >= today {
            return thisYear
        }

        // 이미 지났으면 내년 반환
        return clamped(year: currentYear + 1, month: month, day: day, calendar: calendar) ?? today
    }

    /// 주어진 연·월·일로 Date를 생성한다.
    /// day가 그 달의 최대 일수를 넘으면 마지막 날로 맞춤 (예: 11월 31일 → 11월 30일).
    /// - dayRange: Calendar.range(of: .day, in: .month)는 1..<(최대일수+1) 형태
    private static func clamped(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components   = DateComponents()
        components.year  = year
        components.month = month
        components.day   = 1  // 1일로 먼저 만들어 그 달의 범위를 구함

        guard let firstOfMonth = calendar.date(from: components),
              let dayRange     = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return nil
        }

        // upperBound - 1 이 그 달의 마지막 날짜 (예: 1..<31 → 30일)
        components.day = min(day, dayRange.upperBound - 1)
        return calendar.date(from: components)
    }
}
