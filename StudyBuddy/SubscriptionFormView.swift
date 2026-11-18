import SwiftUI
import SwiftData

// MARK: - 구독 추가 / 수정 폼
// subscription이 nil이면 추가, 값이 있으면 수정으로 동작하는 단일 화면
struct SubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.accountID) private var accounts: [Account]
    // 중복 여부 판단을 위해 전체 구독 목록을 불러옴
    @Query private var allSubscriptions: [Subscription]

    var subscription: Subscription?

    // 중복 등록 Alert 표시 여부
    @State private var showDuplicateAlert = false
    // 새 구독의 기본 알림 시점 (설정 탭에서 변경 가능)
    @AppStorage("defaultNotifyDaysBefore") private var defaultNotifyDays = 3

    // MARK: 프리셋 선택 상태
    // "" = 직접 입력, 프리셋 이름이면 해당 서비스 선택
    @State private var presetServiceName: String = ""
    @State private var presetPlanName: String    = ""

    // 현재 선택된 프리셋 서비스 (계산 프로퍼티)
    private var selectedPreset: ServicePreset? {
        ServicePreset.all.first { $0.name == presetServiceName }
    }

    // MARK: 폼 상태 변수 — 저장 버튼을 눌러야 모델에 반영됨
    @State private var name: String
    @State private var planName: String
    @State private var fee: Int
    @State private var hasWebFee: Bool
    @State private var webFee: Int
    @State private var billingCycle: BillingCycle
    @State private var billingMonth: Int
    @State private var billingDay: Int
    @State private var hasTrial: Bool
    @State private var trialEndDate: Date
    @State private var paymentRoute: PaymentRoute
    @State private var sharedCount: Int
    @State private var category: String
    @State private var selectedAccount: Account?

    init(subscription: Subscription?) {
        self.subscription    = subscription
        _name            = State(initialValue: subscription?.name ?? "")
        _planName        = State(initialValue: subscription?.planName ?? "")
        _fee             = State(initialValue: subscription?.fee ?? 0)
        _hasWebFee       = State(initialValue: subscription?.webFee != nil)
        _webFee          = State(initialValue: subscription?.webFee ?? 0)
        _billingCycle    = State(initialValue: subscription?.billingCycle ?? .monthly)
        _billingMonth    = State(initialValue: subscription?.billingMonth ?? 1)
        _billingDay      = State(initialValue: subscription?.billingDay ?? 1)
        _hasTrial        = State(initialValue: subscription?.trialEndDate != nil)
        _trialEndDate    = State(initialValue: subscription?.trialEndDate ?? Date())
        _paymentRoute    = State(initialValue: subscription?.paymentRoute ?? .web)
        _sharedCount     = State(initialValue: subscription?.sharedCount ?? 1)
        _category        = State(initialValue: subscription?.category ?? "기타")
        _selectedAccount = State(initialValue: subscription?.account)
        // 프리셋은 항상 "직접 입력"으로 시작
        _presetServiceName = State(initialValue: "")
        _presetPlanName    = State(initialValue: "")
    }

    // 서비스명이 비어 있거나 금액이 0 이하면 저장 버튼 비활성화
    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty || fee <= 0
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: 프리셋에서 선택 섹션
                Section {
                    // 1) 서비스 선택 — "직접 입력" 포함
                    Picker("서비스", selection: $presetServiceName) {
                        Text("직접 입력").tag("")
                        ForEach(ServicePreset.all, id: \.name) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                    }

                    // 2) 요금제 선택 — 프리셋 서비스가 선택됐을 때만 표시
                    if let preset = selectedPreset {
                        Picker("요금제", selection: $presetPlanName) {
                            ForEach(preset.plans, id: \.name) { plan in
                                Text(plan.name).tag(plan.name)
                            }
                        }
                    }

                    // 3) 결제 경로 — 경로에 따라 fee가 자동 재계산됨
                    Picker("결제 경로", selection: $paymentRoute) {
                        ForEach(PaymentRoute.allCases, id: \.self) { route in
                            Text(route.rawValue).tag(route)
                        }
                    }

                } header: {
                    Text("프리셋에서 선택")
                } footer: {
                    // 가격 기준 날짜 안내
                    Text(ServicePreset.priceBaseDate)
                }

                // MARK: 서비스 정보 섹션
                Section("서비스 정보") {
                    TextField("서비스명 (필수)", text: $name)
                    TextField("요금제명", text: $planName)

                    Picker("카테고리", selection: $category) {
                        ForEach(subscriptionCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                // MARK: 결제 정보 섹션
                Section("결제 정보") {
                    // 금액 — 프리셋 선택 시 자동 채워지지만 직접 수정 가능
                    HStack {
                        Text("금액 (필수)")
                        Spacer()
                        TextField("0", value: $fee, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("원")
                    }

                    Picker("결제 주기", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.rawValue).tag(cycle)
                        }
                    }

                    if billingCycle == .yearly {
                        Picker("결제 월", selection: $billingMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)월").tag(month)
                            }
                        }
                    }

                    Stepper("결제일: \(billingDay)일", value: $billingDay, in: 1...31)

                    // 웹 결제 금액 비교 — 프리셋 선택 시 자동 활성화
                    Toggle("웹 결제 금액 비교", isOn: $hasWebFee)
                    if hasWebFee {
                        HStack {
                            Text("웹 결제 금액")
                            Spacer()
                            TextField("0", value: $webFee, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("원")
                        }
                    }
                }

                // MARK: 무료체험 섹션
                Section("무료체험") {
                    Toggle("무료체험 중", isOn: $hasTrial)
                    if hasTrial {
                        DatePicker("종료일", selection: $trialEndDate,
                                   displayedComponents: .date)
                    }
                }

                // MARK: 추가 정보 섹션
                Section("추가 정보") {
                    Stepper("공유 인원: \(sharedCount)명", value: $sharedCount, in: 1...10)
                }

                // MARK: 가입 계정 섹션
                Section("가입 계정") {
                    Picker("계정", selection: $selectedAccount) {
                        Text("계정 없음").tag(Optional<Account>.none)
                        ForEach(accounts) { account in
                            Text(account.accountID).tag(Optional(account))
                        }
                    }
                }
            }
            // MARK: 프리셋 onChange 핸들러
            // 서비스가 바뀌면 → 이름·카테고리 채우고 첫 요금제 자동 선택
            .onChange(of: presetServiceName) { _, newName in
                guard let preset = ServicePreset.all.first(where: { $0.name == newName }),
                      let first  = preset.plans.first else { return }
                name     = preset.name
                category = preset.category
                presetPlanName = first.name
                applyPlan(first)
            }
            // 요금제가 바뀌면 → planName·fee·webFee 채움
            .onChange(of: presetPlanName) { _, newPlanName in
                guard let plan = selectedPreset?.plans.first(where: { $0.name == newPlanName }) else { return }
                applyPlan(plan)
            }
            // 결제 경로가 바뀌면 → 프리셋 요금제가 있으면 fee 재계산
            .onChange(of: paymentRoute) { _, _ in
                guard let plan = selectedPreset?.plans.first(where: { $0.name == presetPlanName }) else { return }
                updateFee(from: plan)
            }
            .navigationTitle(subscription == nil ? "구독 추가" : "구독 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        // 같은 서비스 + 같은 계정이 이미 존재하면 저장하지 않고 Alert 표시
                        if DuplicateChecker.isAlreadyRegistered(
                            name: name,
                            account: selectedAccount,
                            in: allSubscriptions,
                            excluding: subscription   // 수정 시 자기 자신 제외
                        ) {
                            showDuplicateAlert = true
                        } else {
                            save()
                            dismiss()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
            // 중복 등록 경고 Alert
            .alert("이미 등록된 구독이에요", isPresented: $showDuplicateAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("같은 계정에 '\(name)' 구독이 이미 있어요.\n다른 계정을 선택하거나 기존 구독을 수정해주세요.")
            }
        }
    }

    // MARK: - 프리셋 자동 채움

    /// 선택된 요금제로 planName·fee·webFee를 한꺼번에 채움
    private func applyPlan(_ plan: PlanPreset) {
        planName   = plan.name
        // 웹 결제 금액은 항상 webFee 속성에 저장
        webFee     = plan.webFee
        hasWebFee  = plan.webFee > 0  // 금액이 0인 플레이스홀더는 비교 토글 OFF
        updateFee(from: plan)
    }

    /// 결제 경로에 따라 fee를 계산
    /// 인앱 결제 금액이 없으면(nil) 웹 결제 금액으로 대체
    private func updateFee(from plan: PlanPreset) {
        if paymentRoute == .inApp {
            fee = plan.inAppFee ?? plan.webFee
        } else {
            fee = plan.webFee
        }
    }

    // MARK: - 저장 로직
    private func save() {
        if let subscription {
            subscription.name         = name
            subscription.planName     = planName
            subscription.fee          = fee
            subscription.webFee       = hasWebFee ? webFee : nil
            subscription.billingCycle = billingCycle
            subscription.billingMonth = billingCycle == .yearly ? billingMonth : nil
            subscription.billingDay   = billingDay
            subscription.trialEndDate = hasTrial ? trialEndDate : nil
            subscription.paymentRoute = paymentRoute
            subscription.sharedCount  = sharedCount
            subscription.category     = category
            subscription.account      = selectedAccount
            // 결제일이 바뀌었을 수 있으므로 알림 재예약
            NotificationManager.shared.schedule(for: subscription)
        } else {
            let new = Subscription(
                name: name,
                planName: planName,
                fee: fee,
                webFee: hasWebFee ? webFee : nil,
                billingCycle: billingCycle,
                billingMonth: billingCycle == .yearly ? billingMonth : nil,
                billingDay: billingDay,
                trialEndDate: hasTrial ? trialEndDate : nil,
                paymentRoute: paymentRoute,
                sharedCount: sharedCount,
                category: category,
                // 설정 탭에서 지정한 기본 알림 시점 적용
                notifyDaysBefore: defaultNotifyDays,
                account: selectedAccount
            )
            modelContext.insert(new)
            NotificationManager.shared.schedule(for: new)
        }
    }
}

#Preview {
    SubscriptionFormView(subscription: nil)
        .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
