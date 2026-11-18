import SwiftUI
import SwiftData

// MARK: - 계정 관리 목록 화면
struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.accountID) private var accounts: [Account]

    @State private var showingAddSheet  = false
    @State private var accountToEdit:   Account? = nil
    // 삭제 확인 Dialog에 사용할 대상 계정
    @State private var accountToDelete: Account? = nil

    var body: some View {
        Group {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "계정이 없어요",
                    systemImage: "person.crop.circle",
                    description: Text("+ 버튼으로 가입 계정을 추가해보세요")
                )
            } else {
                List {
                    ForEach(accounts) { account in
                        // 행 탭 → 수정 Sheet 열기
                        Button {
                            accountToEdit = account
                        } label: {
                            AccountRow(account: account)
                        }
                        .tint(.primary)
                        // 스와이프 삭제: 즉시 삭제하지 않고 confirmationDialog 먼저 표시
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                accountToDelete = account
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("계정 관리")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // 계정 추가 Sheet
        .sheet(isPresented: $showingAddSheet) {
            AccountFormView(account: nil)
        }
        // 계정 수정 Sheet — item 버전: account가 nil이 아닐 때 자동으로 열림
        .sheet(item: $accountToEdit) { account in
            AccountFormView(account: account)
        }
        // ── cascade 삭제 경고 Dialog ──────────────────────────────────────
        // accountToDelete가 nil이 아닐 때 표시
        // isPresented를 Binding<Bool>로 변환해 accountToDelete 상태로 제어
        .confirmationDialog(
            "계정을 삭제할까요?",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = accountToDelete {
                let count = target.subscriptions.count
                // 구독이 있으면 연쇄 삭제 경고, 없으면 단순 삭제
                Button(count > 0 ? "구독 \(count)개와 함께 삭제" : "삭제",
                       role: .destructive) {
                    // cascade 삭제 전에 연결된 구독의 알림을 먼저 취소
                    for sub in target.subscriptions {
                        NotificationManager.shared.cancel(for: sub)
                    }
                    modelContext.delete(target)   // cascade: 연결된 Subscription도 삭제됨
                    accountToDelete = nil
                }
                Button("취소", role: .cancel) {
                    accountToDelete = nil
                }
            }
        } message: {
            if let target = accountToDelete {
                let count = target.subscriptions.count
                if count > 0 {
                    // cascade 동작을 사용자에게 명확히 알림
                    Text("'\(target.accountID)' 계정의 구독 \(count)개도 함께 삭제됩니다.")
                } else {
                    Text("'\(target.accountID)' 계정을 삭제합니다.")
                }
            }
        }
    }
}

// MARK: - 계정 행 서브뷰
private struct AccountRow: View {
    let account: Account

    // 연결된 구독의 월 환산 합계
    private var monthlyTotal: Int {
        account.subscriptions.reduce(0) { acc, sub in
            acc + (sub.billingCycle == .yearly ? sub.fee / 12 : sub.fee)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.accountID)
                .font(.headline)
                .foregroundStyle(.primary)

            if !account.memo.isEmpty {
                Text(account.memo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 연결된 구독 수 · 월 금액
            HStack(spacing: 4) {
                Text("구독 \(account.subscriptions.count)개")
                Text("·")
                Text("월 \(monthlyTotal.formatted())원")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 계정 추가 / 수정 폼
// ⚠️ 비밀번호 입력란은 절대 추가하지 않음 — 아이디/이메일만 저장
struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var account: Account?

    @State private var accountID: String
    @State private var memo: String

    init(account: Account?) {
        self.account = account
        _accountID = State(initialValue: account?.accountID ?? "")
        _memo      = State(initialValue: account?.memo ?? "")
    }

    private var isSaveDisabled: Bool {
        accountID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("아이디 / 이메일", text: $accountID)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    TextField("메모 (선택)", text: $memo)
                } header: {
                    Text("계정 정보")
                } footer: {
                    // 비밀번호를 저장하지 않는 이유를 사용자에게 안내
                    Text("비밀번호는 저장하지 않습니다. 아이디 또는 이메일만 입력하세요.")
                }
            }
            .navigationTitle(account == nil ? "계정 추가" : "계정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private func save() {
        if let account {
            account.accountID = accountID
            account.memo      = memo
        } else {
            modelContext.insert(Account(accountID: accountID, memo: memo))
        }
    }
}

// MARK: - Identifiable 확장 (sheet(item:) 사용을 위해)
// @Model 클래스는 PersistentModel을 통해 이미 Identifiable을 충족하므로 추가 불필요

#Preview {
    NavigationStack {
        AccountListView()
    }
    .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
