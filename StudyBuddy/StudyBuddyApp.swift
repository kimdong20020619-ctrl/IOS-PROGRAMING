import SwiftUI
import SwiftData

@main
struct StudyBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Account와 Subscription 두 모델을 SwiftData로 관리
        // Account → Subscription 관계가 있으므로 둘 다 등록
        .modelContainer(for: [Account.self, Subscription.self])
    }
}
