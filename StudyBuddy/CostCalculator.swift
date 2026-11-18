import Foundation

// MARK: - 비용 계산기

/// 구독 금액을 월/연 단위로 환산하고 절약액을 계산하는 유틸리티
/// - 모든 반환값은 Int 원 단위
/// - 나눗셈은 반올림 (Int(Double.rounded()))
enum CostCalculator {

    // MARK: 단일 구독 계산

    /// 구독의 월 환산 금액
    /// 매월 결제: fee 그대로 / 매년 결제: fee ÷ 12 반올림
    ///
    /// 손계산 예시:
    ///   애플 원 연간 99,000원  →  99,000 ÷ 12 = 8,250.0  →  8,250원
    ///   넷플릭스 월 17,000원   →  17,000원 (그대로)
    static func monthlyEquivalent(_ s: Subscription) -> Int {
        switch s.billingCycle {
        case .monthly: return s.fee
        case .yearly:  return Int((Double(s.fee) / 12.0).rounded())
        }
    }

    /// 1인당 월 금액 (monthlyEquivalent ÷ sharedCount, 반올림)
    ///
    /// 손계산 예시:
    ///   넷플릭스 17,000원 2인 공유  →  17,000 ÷ 2 = 8,500원
    ///   유튜브 프리미엄 14,900원 1인  →  14,900 ÷ 1 = 14,900원 (그대로)
    static func perPerson(_ s: Subscription) -> Int {
        let monthly = monthlyEquivalent(s)
        guard s.sharedCount > 1 else { return monthly }
        return Int((Double(monthly) / Double(s.sharedCount)).rounded())
    }

    /// 결제 경로를 웹으로 바꿨을 때 월 절약 가능액
    /// - 인앱 결제이고 webFee가 존재할 때만 계산 (그 외 0)
    /// - 매년 결제이면 연 차액을 ÷ 12 반올림해 월 단위로 환산
    ///
    /// 손계산 예시 (월간):
    ///   유튜브 인앱 19,500 / 웹 14,900  →  19,500 - 14,900 = 4,600원/월
    ///
    /// 손계산 예시 (연간):
    ///   연간 인앱 120,000 / 웹 96,000  →  (120,000 - 96,000) ÷ 12 = 2,000원/월
    static func routeSaving(_ s: Subscription) -> Int {
        guard s.paymentRoute == .inApp, let webFee = s.webFee else { return 0 }
        let diff = s.fee - webFee
        guard diff > 0 else { return 0 }  // 웹이 더 비싼 이상한 경우 방어
        if s.billingCycle == .yearly {
            return Int((Double(diff) / 12.0).rounded())
        } else {
            return diff
        }
    }

    // MARK: 전체 목록 계산

    /// 전체 구독 월 합계
    ///
    /// 손계산 예시:
    ///   넷플릭스 17,000 + 유튜브 14,900 + 애플 원 8,250 + 스포티파이 10,900
    ///   = 51,050원
    static func monthlyTotal(_ list: [Subscription]) -> Int {
        list.reduce(0) { $0 + monthlyEquivalent($1) }
    }

    /// 연간 예상 지출액 (monthlyTotal × 12)
    ///
    /// 손계산 예시:
    ///   월 합계 51,050원  →  51,050 × 12 = 612,600원
    static func yearlyEstimate(_ list: [Subscription]) -> Int {
        monthlyTotal(list) * 12
    }

    /// 전체 구독의 결제 경로 절약 가능액 연간 합계
    /// = 각 구독 routeSaving(월 단위) 합 × 12
    ///
    /// 손계산 예시:
    ///   유튜브 월 4,600 + 넷플릭스 월 3,500 = 월 8,100
    ///   8,100 × 12 = 97,200원/년
    static func yearlyRouteSaving(_ list: [Subscription]) -> Int {
        list.reduce(0) { $0 + routeSaving($1) } * 12
    }
}
