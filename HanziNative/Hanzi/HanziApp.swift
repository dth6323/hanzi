import SwiftUI

@main
struct HanziApp: App {
    init() {
        // Navigation bar dark appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.07, green: 0.06, blue: 0.06, alpha: 1.0)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.96, green: 0.94, blue: 0.92, alpha: 1.0)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.96, green: 0.94, blue: 0.92, alpha: 1.0)
        ]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.90, green: 0.28, blue: 0.23, alpha: 1.0)
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .background(Theme.background)
        }
    }
}
