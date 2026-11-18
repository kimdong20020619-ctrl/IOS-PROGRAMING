import SwiftUI
import SwiftData

// MARK: - 구독 목록 화면
struct SubscriptionListView: View {
    @Environment(\.modelContext) private var modelContext

    // @Query는 저장된 프로퍼티 기준으로만 정렬 가능하므로 기본 정렬로 가져온 후
    // 클라이언트에서 다음 결제일 순으로 재정렬
    @Query private var subscriptions: [Subscription]

    @State private var showingAddSheet = false

    /// 다음 결제일이 가까운 순으로 정렬한 목록
    private var sortedSubscriptions: [Subscription] {
        subscriptions.sorted {
            BillingCalculator.nextBillingDate(for: $0) < BillingCalculator.nextBillingDate(for: $1)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "구독이 없어요",
                        systemImage: "creditcard",
                        description: Text("+ 버튼으로 첫 구독을 추가해보세요")
                    )
                } else {
                    List {
                        ForEach(sortedSubscriptions) { subscription in
                            NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                SubscriptionRow(subscription: subscription)
                            }
                        }
                        // 스와이프 삭제: sortedSubscriptions 인덱스 기준으로 정확한 항목 삭제
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("구독")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SubscriptionFormView(subscription: nil)
            }
        }
    }

    // sortedSubscriptions 기준 인덱스로 올바른 항목을 삭제
    private func delete(at offsets: IndexSet) {
        let sorted = sortedSubscriptions
        for index in offsets {
            NotificationManager.shared.cancel(for: sorted[index])
            modelContext.delete(sorted[index])
        }
    }
}

// MARK: - 목록 행 서브뷰
private struct SubscriptionRow: View {
    let subscription: Subscription

    // 같은 계산을 여러 번 호출하지 않도록 미리 계산
    private var nextDate: Date       { BillingCalculator.nextBillingDate(for: subscription) }
    private var status: BillingStatus { BillingCalculator.billingStatus(for: subscription) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // 1행: 서비스명 + 결제 경로 뱃지 + 상태 뱃지
            HStack {
                Text(subscription.name)
                    .font(.headline)
                Spacer()
                // 결제 경로 뱃지: 웹(파랑) / 앱(초록)
                PaymentRouteBadge(route: subscription.paymentRoute)
                // 임박 상태 뱃지: normal은 label 빈 문자열 → 미표시
                if !status.label.isEmpty {
                    BillingBadge(status: status)
                }
            }

            // 2행: 요금제명 (있을 때만)
            if !subscription.planName.isEmpty {
                Text(subscription.planName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 3행: 무료체험 카운트다운 OR 다음 결제 예정일
            if let trialEnd = subscription.trialEndDate,
               BillingCalculator.daysUntil(trialEnd) >= 0 {
                // 무료체험 종료일이 오늘 이후: 남은 일수 표시
                Text("체험 종료까지 \(BillingCalculator.daysUntil(trialEnd))일")
                    .font(.caption)
                    .foregroundStyle(.blue)
            } else {
                // 무료체험 없음 or 종료됨: 다음 결제일 표시
                // 오늘·내일은 status.color(빨강·주황), 그 외는 보조색
                Text("\(formatDate(nextDate)) 결제 예정")
                    .font(.caption)
                    .foregroundStyle(status.color)
            }

            // 4행: 금액 · 결제 주기
            HStack(spacing: 4) {
                Text("\(subscription.fee.formatted())원")
                Text("·")
                Text(subscription.billingCycle.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    /// Date를 "12월 5일" 형태의 한국어 문자열로 변환
    private func formatDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
            .month(.defaultDigits)
            .day()
            .locale(Locale(identifier: "ko_KR"))
        )
    }
}

// MARK: - 결제 경로 뱃지 ("웹" / "앱")
private struct PaymentRouteBadge: View {
    let route: PaymentRoute

    private var label: String { route == .web ? "웹" : "앱" }
    // 웹은 파란 계열, 인앱은 초록 계열로 구분
    private var color: Color  { route == .web ? .blue : .green }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - 임박 상태 뱃지
private struct BillingBadge: View {
    let status: BillingStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color, in: Capsule())
    }
}

#Preview {
    SubscriptionListView()
        .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
