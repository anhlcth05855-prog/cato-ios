import SwiftUI

@main
struct CatoApp: App {

    init() {
        // Giữ màn hình luôn sáng khi đang chạy xe trên cao tốc
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
    }
}
