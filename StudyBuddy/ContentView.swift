import SwiftUI
import SwiftData

// MARK: - 루트 화면: 4개 탭
struct ContentView: View {
    // 앱이 활성화될 때 알림 전체 재예약에 필요
    @Query private var subscriptions: [Subscription]
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            SubscriptionListView()
                .tabItem { Label("구독", systemImage: "list.bullet") }

            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }

            DashboardView()
                .tabItem { Label("대시보드", systemImage: "chart.pie") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        // 앱이 포그라운드로 돌아올 때마다 알림 재계산
        // "다음 결제일 하나만 예약" 방식이므로 주기적으로 갱신 필요
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationManager.shared.rescheduleAll(subscriptions)
            }
        }
    }
}

// MARK: - 설정 화면
private struct SettingsView: View {
    private let notifManager = NotificationManager.shared
    // 새 구독을 추가할 때 기본으로 적용되는 알림 시점 (UserDefaults 영구 저장)
    @AppStorage("defaultNotifyDaysBefore") private var defaultDays = 3
    @State private var showTestScheduledAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: 알림 섹션
                Section {
                    // 현재 권한 상태 표시
                    HStack {
                        Text("알림 권한")
                        Spacer()
                        Text(statusLabel)
                            .foregroundStyle(statusColor)
                    }

                    // 권한 미설정 → 요청 버튼
                    if notifManager.authorizationStatus == .notDetermined {
                        Button("알림 권한 요청") {
                            Task { await notifManager.requestPermission() }
                        }
                    }
                    // 거부됨 → 시스템 설정으로 이동
                    if notifManager.authorizationStatus == .denied {
                        Button("설정에서 알림 켜기") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Task { await UIApplication.shared.open(url) }
                            }
                        }
                    }

                    // 기본 알림 시점 — 새 구독을 저장할 때 이 값이 notifyDaysBefore에 적용됨
                    Picker("기본 알림 시점", selection: $defaultDays) {
                        Text("1일 전").tag(1)
                        Text("3일 전").tag(3)
                        Text("7일 전").tag(7)
                    }

                    // 테스트 알림 — 허용됨 상태일 때만 활성화
                    Button("10초 뒤 테스트 알림 보내기") {
                        notifManager.sendTestNotification()
                        showTestScheduledAlert = true
                    }
                    .disabled(notifManager.authorizationStatus != .authorized)

                } header: {
                    Text("알림")
                }

                // MARK: 계정 관리
                Section {
                    NavigationLink(destination: AccountListView()) {
                        Label("계정 관리", systemImage: "person.crop.circle")
                    }
                }
            }
            .navigationTitle("설정")
            // 화면이 열릴 때마다 최신 권한 상태를 반영
            .task { await notifManager.updateStatus() }
            .alert("테스트 알림이 예약됐어요", isPresented: $showTestScheduledAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("10초 뒤 알림이 옵니다. 앱을 백그라운드로 내리거나 그냥 두세요.")
            }
        }
    }

    private var statusLabel: String {
        switch notifManager.authorizationStatus {
        case .authorized:    return "허용됨"
        case .denied:        return "거부됨"
        case .provisional:   return "임시 허용"
        case .notDetermined: return "미설정"
        @unknown default:    return "알 수 없음"
        }
    }

    private var statusColor: Color {
        switch notifManager.authorizationStatus {
        case .authorized: return .green
        case .denied:     return .red
        default:          return .orange
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
