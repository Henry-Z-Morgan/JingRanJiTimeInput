import SwiftUI

/// 将 `Examples/TimeInputShowcase` 整个目录加入任意 iOS 16+ SwiftUI App Target 后可直接运行。
@main
struct TimeInputShowcaseApp: App {
    var body: some Scene {
        WindowGroup {
            TimeInputShowcaseView()
        }
    }
}
