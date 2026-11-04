import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.06, blue: 0.06, alpha: 1.0) // #12100F
        
        // Active item
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.90, green: 0.28, blue: 0.23, alpha: 1.0) // Vermilion
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.90, green: 0.28, blue: 0.23, alpha: 1.0)
        ]
        
        // Normal item
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 1.0)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Tra cứu
            NavigationStack {
                SearchScreenView()
            }
            .tabItem {
                Label("Tra cứu", systemImage: "magnifyingglass")
            }
            .tag(0)
            
            // Tab 2: Luyện viết
            NavigationStack {
                WritingHomeView()
            }
            .tabItem {
                Label("Luyện viết", systemImage: "pencil.and.outline")
            }
            .tag(1)
            
            // Tab 3: Học tập
            NavigationStack {
                LearnHomeView()
            }
            .tabItem {
                Label("Học tập", systemImage: "graduationcap")
            }
            .tag(2)
            
            // Tab 4: Sổ tay
            NavigationStack {
                NotebookView()
            }
            .tabItem {
                Label("Sổ tay", systemImage: "book")
            }
            .tag(3)
        }
        .tint(Theme.vermilion)
    }
}
