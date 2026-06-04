import SwiftUI

struct ContentView: View {
    init() {
        // Customize TabBar to fit the theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "F9F9F7"))
        
        // Active item color (Ink)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "1A1A1A"))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "1A1A1A"))]
        
        // Inactive item color (Gray)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            
            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            
            NavigationStack {
                FileBrowserView()
            }
            .tabItem {
                Label("Files", systemImage: "folder")
            }
            
            TranscriptionView()
                .tabItem {
                    Label("Voice", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("System", systemImage: "gearshape")
                }
        }
        .accentColor(AppTheme.ink)
    }
}

#Preview {
    ContentView()
}
