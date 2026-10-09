import SwiftUI
import UIKit

@main
struct CatoApp: App {

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
