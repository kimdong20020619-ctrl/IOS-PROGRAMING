import SwiftUI
import SwiftData

// MARK: - 대시보드 메인 화면
struct DashboardView: View {
    @Query private var subscriptions: [Subscription]
    @Query(sort: \Account.accountID) private var accounts: [Account]

    // 오늘 포함 7일 이내 결제 예정 건수
    private var upcomingCount: Int {
        subscriptions.filter {
            let days = BillingCalculator.daysUntil(
                BillingCalculator.nextBillingDate(for: $0))
            return (0...6).contains(days)
        }.count
    }

    // 인앱 결제 절약 가능한 구독 (routeSaving > 0), 절약액 큰 순
    private var routeSavingSubs: [Subscription] {
        subscriptions
            .filter { CostCalculator.routeSaving($0) > 0 }
            .sorted { CostCalculator.routeSaving($0) > CostCalculator.routeSaving($1) }
    }

    // 중복 구독 그룹
    private var duplicateGroups: [DuplicateGroup] {
        DuplicateChecker.duplicates(in: subscriptions)
    }

    // 연간 절약 가능 총액 (경로 절약 + 중복 해지)
    // 중복 그룹의 savingsIfCancelled는 월 단위이므로 × 12
    private var totalYearlySavings: Int {
        let routeSavings = CostCalculator.yearlyRouteSaving(subscriptions)
        let dupSavings   = duplicateGroups.reduce(0) { $0 + $1.savingsIfCancelled } * 12
        return routeSavings + dupSavings
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "구독이 없어요",
                        systemImage: "chart.pie",
                        description: Text("구독 탭에서 첫 구독을 추가하면 여기에 통계가 표시돼요")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 1. 이번 달 요약
                            SummaryCard(
                                count: subscriptions.count,
                                monthlyTotal: CostCalculator.monthlyTotal(subscriptions),
                                yearlyEstimate: CostCalculator.yearlyEstimate(subscriptions),
                                upcomingCount: upcomingCount
                            )

                            // 2. 계정별 요약
                            AccountBreakdownCard(
                                accounts: accounts,
                                subscriptions: subscriptions
                            )

                            // 3. 절약 제안
                            SavingsCard(
                                routeSavingSubs: routeSavingSubs,
                                duplicateGroups: duplicateGroups,
                                totalYearlySavings: totalYearlySavings
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("대시보드")
        }
    }
}

// MARK: - 카드 컨테이너 (공통 스타일)

/// 타이틀 + 콘텐츠를 감싸는 둥근 카드
private struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 통계 행 (레이블 + 값)

private struct StatRow: View {
    let label: String
    let value: String
    var isBold: Bool    = false
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundStyle(valueColor)
        }
        .font(.subheadline)
    }
}

// MARK: - 1. 이번 달 요약 카드

private struct SummaryCard: View {
    let count: Int
    let monthlyTotal: Int
    let yearlyEstimate: Int
    let upcomingCount: Int

    var body: some View {
        DashboardCard(title: "이번 달 요약") {
            StatRow(label: "구독 수", value: "\(count)개")
            Divider()
            // 월 합계는 강조 표시
            StatRow(label: "월 합계",
                    value: "\(monthlyTotal.formatted())원",
                    isBold: true)
            Divider()
            StatRow(label: "연간 예상",
                    value: "\(yearlyEstimate.formatted())원")
            Divider()
            // 이번 주 결제 건수가 있으면 주황으로 강조
            StatRow(label: "7일 내 결제 예정",
                    value: "\(upcomingCount)건",
                    valueColor: upcomingCount > 0 ? .orange : .secondary)
        }
    }
}

// MARK: - 2. 계정별 요약 카드

private struct AccountBreakdownCard: View {
    let accounts: [Account]
    let subscriptions: [Subscription]

    // accountID(String?)를 키로 구독을 그룹핑
    // nil 키 = "계정 없음" 그룹
    private var subsByAccountID: [String?: [Subscription]] {
        Dictionary(grouping: subscriptions) { $0.account?.accountID }
    }

    // 구독이 1개 이상 있는 계정만 표시
    private var activeAccounts: [Account] {
        accounts.filter { subsByAccountID[$0.accountID] != nil }
    }

    // 계정 없음 구독
    private var noAccountSubs: [Subscription] {
        subsByAccountID[nil] ?? []
    }

    var body: some View {
        DashboardCard(title: "계정별 요약") {
            if activeAccounts.isEmpty && noAccountSubs.isEmpty {
                Text("연결된 계정이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    // 계정별 행
                    ForEach(activeAccounts) { account in
                        let subs    = subsByAccountID[account.accountID] ?? []
                        let monthly = CostCalculator.monthlyTotal(subs)
                        AccountRow(
                            name: account.accountID,
                            memo: account.memo,
                            count: subs.count,
                            monthly: monthly
                        )
                        Divider()
                    }

                    // 계정 없음 행
                    if !noAccountSubs.isEmpty {
                        AccountRow(
                            name: "계정 없음",
                            memo: "",
                            count: noAccountSubs.count,
                            monthly: CostCalculator.monthlyTotal(noAccountSubs)
                        )
                    }
                }
            }
        }
    }
}

/// 계정 한 행
private struct AccountRow: View {
    let name: String
    let memo: String
    let count: Int
    let monthly: Int

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                if !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(monthly.formatted())원")
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - 3. 절약 제안 카드

private struct SavingsCard: View {
    let routeSavingSubs: [Subscription]
    let duplicateGroups: [DuplicateGroup]
    let totalYearlySavings: Int

    private var hasSavings: Bool {
        !routeSavingSubs.isEmpty || !duplicateGroups.isEmpty
    }

    var body: some View {
        DashboardCard(title: "절약 제안") {
            if !hasSavings {
                Text("현재 절약 제안이 없어요 👍")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {

                    // ── 결제 경로 절약 제안 ─────────────────────────────
                    if !routeSavingSubs.isEmpty {
                        SavingsSectionHeader(
                            icon: "creditcard.and.123",
                            title: "결제 경로"
                        )
                        ForEach(routeSavingSubs) { sub in
                            let saving = CostCalculator.routeSaving(sub)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.subheadline)
                                    Text("웹으로 결제하면")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("월 \(saving.formatted())원 절약")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // ── 중복 구독 경고 ──────────────────────────────────
                    if !duplicateGroups.isEmpty {
                        if !routeSavingSubs.isEmpty { Divider() }

                        SavingsSectionHeader(
                            icon: "exclamationmark.triangle",
                            title: "중복 구독"
                        )
                        ForEach(duplicateGroups, id: \.serviceName) { group in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.serviceName)
                                        .font(.subheadline)
                                    Text("\(group.count)개 계정 중복")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("월 \(group.savingsIfCancelled.formatted())원 절약 가능")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    // ── 연간 절약 가능 총액 ─────────────────────────────
                    Divider()
                    HStack {
                        Text("연간 절약 가능 총액")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(totalYearlySavings.formatted())원")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

/// 절약 제안 섹션 헤더 (아이콘 + 제목)
private struct SavingsSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}

// MARK: - 미리보기
#Preview {
    DashboardView()
        .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
