import SwiftUI

@main
struct ShotbinApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var photos = PhotoScanner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(photos)
        }
    }
}
