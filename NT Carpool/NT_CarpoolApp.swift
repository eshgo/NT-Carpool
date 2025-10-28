import SwiftUI
import Firebase
import FirebaseCore

@main
struct NT_CarpoolApp: App {
    init() {
        FirebaseApp.configure()
        
    }
    
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
    }
}
