import Foundation

// MARK: - 요금제 프리셋

/// 하나의 요금제 정보를 담는 구조체
struct PlanPreset {
    let name: String       // 요금제명 (예: "스탠다드")
    let webFee: Int        // 웹·안드로이드 결제 금액
    let inAppFee: Int?     // 아이폰 인앱 결제 금액 (없거나 모르면 nil)
}

// MARK: - 서비스 프리셋

/// 하나의 구독 서비스 프리셋 (서비스명 + 카테고리 + 요금제 목록)
struct ServicePreset {
    let name: String           // 서비스명 (예: "넷플릭스")
    let category: String       // subscriptionCategories 중 하나
    let plans: [PlanPreset]    // 선택 가능한 요금제 목록

    // MARK: 전체 프리셋 목록 (2026년 11월 기준)
    // 금액이 0인 서비스는 나중에 직접 채워줄 것

    /// 가격 기준 날짜 — Section footer에 표시
    static let priceBaseDate = "2026년 11월 기준"

    /// 앱에서 사용할 프리셋 전체 목록
    static let all: [ServicePreset] = [

        // MARK: 영상
        ServicePreset(
            name: "넷플릭스",
            category: "영상",
            plans: [
                PlanPreset(name: "광고형 스탠다드", webFee:  7_000, inAppFee: nil),
                PlanPreset(name: "스탠다드",        webFee: 13_500, inAppFee: nil),
                PlanPreset(name: "프리미엄",        webFee: 17_000, inAppFee: nil),
            ]
        ),
        ServicePreset(
            name: "유튜브 프리미엄",
            category: "영상",
            plans: [
                PlanPreset(name: "프리미엄 라이트", webFee:  8_500, inAppFee: 10_900),
                PlanPreset(name: "프리미엄",        webFee: 14_900, inAppFee: 19_500),
            ]
        ),
        ServicePreset(name: "웨이브",       category: "영상", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "티빙",         category: "영상", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "왓챠",         category: "영상", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "디즈니플러스", category: "영상", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "쿠팡플레이",   category: "영상", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),

        // MARK: 음악
        ServicePreset(name: "스포티파이",   category: "음악", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "애플 뮤직",    category: "음악", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "멜론",         category: "음악", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "지니뮤직",     category: "음악", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),

        // MARK: 쇼핑
        ServicePreset(name: "쿠팡 로켓와우",        category: "쇼핑", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "네이버플러스 멤버십",   category: "쇼핑", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),

        // MARK: 클라우드
        ServicePreset(name: "iCloud+",   category: "클라우드", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "구글 원",   category: "클라우드", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "드롭박스",  category: "클라우드", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),

        // MARK: 기타
        ServicePreset(name: "ChatGPT Plus",          category: "기타", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "Adobe Creative Cloud",  category: "기타", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
        ServicePreset(name: "Microsoft 365",         category: "기타", plans: [PlanPreset(name: "기본", webFee: 0, inAppFee: nil)]),
    ]
}
