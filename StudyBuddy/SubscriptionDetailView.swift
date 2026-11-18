import SwiftUI
import SwiftData

// MARK: - 구독 상세 화면
struct SubscriptionDetailView: View {
    var subscription: Subscription

    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false

    var body: some View {
        List {
            // MARK: 서비스 정보 섹션
            Section("서비스 정보") {
                LabeledContent("서비스명", value: subscription.name)
                if !subscription.planName.isEmpty {
                    LabeledContent("요금제", value: subscription.planName)
                }
                LabeledContent("카테고리", value: subscription.category)
            }

            // MARK: 결제 정보 섹션
            Section("결제 정보") {
                LabeledContent("금액", value: "\(subscription.fee.formatted())원")

                // 웹 결제 금액이 있으면 차액도 함께 표시
                if let webFee = subscription.webFee {
                    LabeledContent("웹 결제 금액", value: "\(webFee.formatted())원")

                    // 인앱 결제가 더 비쌀 경우 차액 강조
                    if subscription.fee > webFee {
                        HStack {
                            Text("결제 경로 차액")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\((subscription.fee - webFee).formatted())원")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }

                LabeledContent("결제 주기", value: subscription.billingCycle.rawValue)

                // 매년 결제일 때만 결제 월 표시
                if subscription.billingCycle == .yearly,
                   let month = subscription.billingMonth {
                    LabeledContent("결제 월", value: "\(month)월")
                }

                LabeledContent("결제일", value: "\(subscription.billingDay)일")
                LabeledContent("결제 경로", value: subscription.paymentRoute.rawValue)
            }

            // MARK: 무료체험 섹션 (종료일이 있을 때만 표시)
            if let trialEnd = subscription.trialEndDate {
                Section("무료체험") {
                    // 날짜만 표시 (시간 제외)
                    LabeledContent("종료일",
                        value: trialEnd.formatted(date: .abbreviated, time: .omitted))

                    // 오늘로부터 남은 일수 계산 (음수면 0으로 처리)
                    let days = Calendar.current
                        .dateComponents([.day], from: .now, to: trialEnd).day ?? 0
                    LabeledContent("남은 일수", value: "\(max(0, days))일")
                }
            }

            // MARK: 추가 정보 섹션
            Section("추가 정보") {
                LabeledContent("공유 인원", value: "\(subscription.sharedCount)명")

                // 가입 계정이 연결된 경우에만 표시
                if let account = subscription.account {
                    LabeledContent("가입 계정", value: account.accountID)
                    if !account.memo.isEmpty {
                        LabeledContent("계정 메모", value: account.memo)
                    }
                }
            }

            // MARK: 알림 섹션
            Section("알림") {
                // notifyEnabled 토글 — 변경 즉시 저장 후 알림 재예약
                Toggle("알림 받기", isOn: notifyEnabledBinding)

                if subscription.notifyEnabled {
                    // notifyDaysBefore 선택 — 변경 즉시 저장 후 재예약
                    Picker("알림 시점", selection: notifyDaysBinding) {
                        Text("1일 전").tag(1)
                        Text("3일 전").tag(3)
                        Text("7일 전").tag(7)
                    }
                }
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 우상단 수정 버튼 → 같은 FormView를 Sheet로 열기
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("수정") { showingEditSheet = true }
            }
        }
        // 수정 Sheet: 현재 subscription 객체를 넘겨 수정 모드로 열기
        .sheet(isPresented: $showingEditSheet) {
            SubscriptionFormView(subscription: subscription)
        }
    }

    // MARK: - 알림 바인딩 헬퍼

    private var notifyEnabledBinding: Binding<Bool> {
        Binding(
            get: { subscription.notifyEnabled },
            set: { newValue in
                subscription.notifyEnabled = newValue
                try? modelContext.save()
                NotificationManager.shared.schedule(for: subscription)
            }
        )
    }

    private var notifyDaysBinding: Binding<Int> {
        Binding(
            get: { subscription.notifyDaysBefore },
            set: { newValue in
                subscription.notifyDaysBefore = newValue
                try? modelContext.save()
                NotificationManager.shared.schedule(for: subscription)
            }
        )
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailView(
            subscription: Subscription(
                name: "넷플릭스",
                planName: "스탠다드",
                fee: 17_000,
                webFee: 13_500,
                billingCycle: .monthly,
                billingDay: 15,
                paymentRoute: .inApp,
                sharedCount: 2,
                category: "영상"
            )
        )
    }
    .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
