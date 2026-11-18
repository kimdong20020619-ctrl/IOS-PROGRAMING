import Foundation

// MARK: - 중복 구독 그룹

/// 같은 서비스명을 가진 중복 구독 묶음
struct DuplicateGroup {
    let serviceName: String
    let subscriptions: [Subscription]

    var count: Int { subscriptions.count }

    /// 월 환산 총 금액 (연간 결제는 ÷12 근사값)
    var totalMonthlyFee: Int {
        subscriptions.reduce(0) { acc, sub in
            acc + (sub.billingCycle == .yearly ? sub.fee / 12 : sub.fee)
        }
    }

    /// 가장 비싼 구독 1개만 남기고 나머지를 해지했을 때 절약 가능한 월 금액
    /// 예: 넷플릭스 17,000 + 넷플릭스 13,500 → 절약액 = 13,500
    var savingsIfCancelled: Int {
        let sortedFees = subscriptions
            .map { $0.billingCycle == .yearly ? $0.fee / 12 : $0.fee }
            .sorted(by: >)      // 내림차순: 비싼 것이 앞에
        // dropFirst()로 가장 비싼 1개를 제외하고 나머지 합산
        return sortedFees.dropFirst().reduce(0, +)
    }
}

// MARK: - 중복 검사기

/// 구독 목록에서 중복을 찾고 신규 등록 중복 여부를 판별하는 유틸리티
enum DuplicateChecker {

    /// 구독 목록에서 중복 그룹을 반환한다.
    ///
    /// **중복 조건**: 서비스명이 같고 계정 아이디가 서로 다른 구독이 2개 이상
    /// - 같은 계정 + 같은 서비스는 isAlreadyRegistered()가 저장 시점에 차단하므로
    ///   duplicates()는 "다른 계정으로 중복 결제"를 주로 잡음
    /// - 절약액이 큰 그룹이 앞에 오도록 정렬
    static func duplicates(in subscriptions: [Subscription]) -> [DuplicateGroup] {
        // 서비스명 소문자 기준으로 그룹핑
        let grouped = Dictionary(grouping: subscriptions) {
            $0.name.trimmingCharacters(in: .whitespaces).lowercased()
        }

        return grouped.compactMap { _, subs in
            guard subs.count >= 2 else { return nil }

            // 계정 아이디 목록 (nil 계정은 빈 문자열로 통일)
            let accountIDs = subs.map { $0.account?.accountID ?? "" }
            // 고유 계정 종류가 2개 미만이면 중복 그룹이 아님
            guard Set(accountIDs).count > 1 else { return nil }

            return DuplicateGroup(serviceName: subs.first!.name, subscriptions: subs)
        }
        .sorted { $0.savingsIfCancelled > $1.savingsIfCancelled }
    }

    /// 같은 서비스명 + 같은 계정의 구독이 이미 존재하는지 확인한다.
    ///
    /// - Parameters:
    ///   - name: 추가/수정하려는 서비스명
    ///   - account: 연결하려는 계정 (nil이면 "계정 없음")
    ///   - subscriptions: 비교할 전체 구독 목록
    ///   - excluding: 수정 중인 구독 자신 — 자기 자신과 비교하지 않기 위해 제외
    /// - Returns: 이미 등록된 중복이면 true
    static func isAlreadyRegistered(
        name: String,
        account: Account?,
        in subscriptions: [Subscription],
        excluding: Subscription? = nil
    ) -> Bool {
        let targetName      = name.trimmingCharacters(in: .whitespaces).lowercased()
        // nil 계정은 빈 문자열로 통일해 비교
        let targetAccountID = account?.accountID ?? ""

        return subscriptions.contains { sub in
            // 수정 중인 구독 자신은 중복 판정에서 제외
            if sub.id == excluding?.id { return false }

            let subName      = sub.name.trimmingCharacters(in: .whitespaces).lowercased()
            let subAccountID = sub.account?.accountID ?? ""

            // 서비스명과 계정 아이디가 모두 같으면 중복
            return subName == targetName && subAccountID == targetAccountID
        }
    }
}
