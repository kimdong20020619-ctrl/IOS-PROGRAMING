import Foundation
import SwiftData

// MARK: - 열거형

/// 결제 주기: 매월 또는 매년
enum BillingCycle: String, Codable, CaseIterable {
    case monthly = "매월"
    case yearly  = "매년"
}

/// 결제 경로: 웹·안드로이드 또는 아이폰 인앱 결제
/// 아이폰 인앱 결제는 애플 수수료(최대 30%)가 붙어 더 비쌀 수 있음
enum PaymentRoute: String, Codable, CaseIterable {
    case web   = "웹·안드로이드"
    case inApp = "아이폰 앱"
}

// MARK: - 카테고리 상수

/// 구독 서비스 카테고리 목록
let subscriptionCategories: [String] = ["영상", "음악", "쇼핑", "클라우드", "기타"]

// MARK: - Account 모델

/// 하나의 가입 계정 정보를 저장하는 모델
/// 비밀번호는 절대 저장하지 않음 — 아이디/이메일만 저장
@Model
final class Account {
    var accountID: String   // 가입 시 사용한 이메일 또는 아이디
    var memo: String        // 메모 (예: "가족 공유 계정")

    /// 이 계정에 연결된 구독 목록
    ///
    /// ## deleteRule: .cascade vs .nullify
    ///
    /// **현재 선택: .cascade (연쇄 삭제)**
    /// Account를 삭제하면 그 계정에 연결된 모든 Subscription도 자동으로 삭제된다.
    /// → "계정을 지우면 그 아래 구독도 없어진다"는 직관적인 동작.
    /// → AccountListView에서 삭제 전 confirmationDialog로 사용자에게 미리 알린다.
    ///
    /// **대안: .nullify (관계 끊기)**
    /// Account를 삭제하면 연결된 Subscription의 account 프로퍼티가 nil로 바뀌고
    /// Subscription 자체는 살아남는다.
    /// → "계정 정보는 지우되 구독 기록은 남긴다"는 동작이 필요할 때 사용.
    /// → 이 앱에서는 계정 없이 구독이 떠다니면 혼란스럽기 때문에 cascade를 선택.
    ///
    /// **정리**: cascade = 부모 삭제 → 자식도 삭제 / nullify = 부모 삭제 → 자식의 외래키만 nil
    @Relationship(deleteRule: .cascade, inverse: \Subscription.account)
    var subscriptions: [Subscription] = []

    init(
        accountID: String = "",
        memo: String = ""
    ) {
        self.accountID = accountID
        self.memo      = memo
    }
}

// MARK: - Subscription 모델

/// 하나의 구독 서비스를 나타내는 모델
@Model
final class Subscription {
    /// UUID — 로컬 알림 식별자로도 사용
    var id: UUID

    var name: String        // 서비스명 (예: 넷플릭스)
    var planName: String    // 요금제명 (예: 스탠다드)
    var fee: Int            // 실제 결제 금액 (원)

    /// 같은 요금제의 웹 결제 금액
    /// 인앱 결제와 비교해 차액을 계산할 때 사용; 모르면 nil
    var webFee: Int?

    var billingCycle: BillingCycle  // 매월 / 매년

    /// 매년 결제일 때의 결제 월 (1~12); 매월이면 nil
    var billingMonth: Int?

    var billingDay: Int     // 결제일 (1~31)

    /// 무료체험 종료일; 체험 중이 아니면 nil
    var trialEndDate: Date?

    var paymentRoute: PaymentRoute  // 웹·안드로이드 / 아이폰 앱

    /// 공유 인원 — 혼자 사용하면 1
    var sharedCount: Int

    var category: String    // subscriptionCategories 중 하나

    /// 알림 활성화 여부
    var notifyEnabled: Bool

    /// 결제일 며칠 전에 알림을 보낼지
    var notifyDaysBefore: Int

    /// 연결된 계정; 계정 정보가 없으면 nil
    var account: Account?

    init(
        id: UUID             = UUID(),
        name: String         = "",
        planName: String     = "",
        fee: Int             = 0,
        webFee: Int?         = nil,
        billingCycle: BillingCycle = .monthly,
        billingMonth: Int?   = nil,
        billingDay: Int      = 1,
        trialEndDate: Date?  = nil,
        paymentRoute: PaymentRoute = .web,
        sharedCount: Int     = 1,
        category: String     = "기타",
        notifyEnabled: Bool  = true,
        notifyDaysBefore: Int = 3,
        account: Account?    = nil
    ) {
        self.id               = id
        self.name             = name
        self.planName         = planName
        self.fee              = fee
        self.webFee           = webFee
        self.billingCycle     = billingCycle
        self.billingMonth     = billingMonth
        self.billingDay       = billingDay
        self.trialEndDate     = trialEndDate
        self.paymentRoute     = paymentRoute
        self.sharedCount      = sharedCount
        self.category         = category
        self.notifyEnabled    = notifyEnabled
        self.notifyDaysBefore = notifyDaysBefore
        self.account          = account
    }
}

// MARK: - 샘플 데이터

/// 미리보기·테스트용 샘플 구독 4개를 ModelContext에 추가하는 함수
/// - 넷플릭스 (인앱, 매월)
/// - 유튜브 프리미엄 (웹, 매월, 차액 있음)
/// - 애플 원 (인앱, 매년)
/// - 스포티파이 (무료체험 중)
@MainActor
func insertSampleData(into context: ModelContext) {
    // 넷플릭스 — 인앱 결제라 웹보다 비쌈
    let netflix = Subscription(
        name: "넷플릭스",
        planName: "스탠다드",
        fee: 17_000,
        webFee: 13_500,         // 웹 결제 시 차액 3,500원
        billingCycle: .monthly,
        billingDay: 15,
        paymentRoute: .inApp,
        sharedCount: 2,
        category: "영상"
    )

    // 유튜브 프리미엄 — 웹 결제, 가족 플랜
    let youtube = Subscription(
        name: "유튜브 프리미엄",
        planName: "개인",
        fee: 14_900,
        billingCycle: .monthly,
        billingDay: 3,
        paymentRoute: .web,
        sharedCount: 1,
        category: "영상"
    )

    // 애플 원 — 매년 결제 (11월)
    let appleOne = Subscription(
        name: "애플 원",
        planName: "개인",
        fee: 69_000,
        billingCycle: .yearly,
        billingMonth: 11,
        billingDay: 20,
        paymentRoute: .inApp,
        sharedCount: 1,
        category: "클라우드"
    )

    // 스포티파이 — 무료체험 종료일이 7일 뒤
    let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    let spotify = Subscription(
        name: "스포티파이",
        planName: "프리미엄",
        fee: 10_900,
        billingCycle: .monthly,
        billingDay: 25,
        trialEndDate: trialEnd,     // 7일 뒤 무료체험 종료
        paymentRoute: .web,
        sharedCount: 1,
        category: "음악"
    )

    // ModelContext에 삽입
    context.insert(netflix)
    context.insert(youtube)
    context.insert(appleOne)
    context.insert(spotify)
}
