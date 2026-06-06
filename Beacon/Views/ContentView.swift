import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ZStack {
                switch selectedTab {
                case 0:
                    ChatView()
                case 1:
                    NavigationStack {
                        TasksView()
                    }
                case 2:
                    NavigationStack {
                        FileBrowserView()
                    }
                case 3:
                    TranscriptionView()
                case 4:
                    SettingsView()
                default:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Mondrian Tab Bar
            HStack(spacing: 0) {
                tabButton(index: 0, title: "Chat", systemImage: "bubble.left.and.bubble.right")
                tabButton(index: 1, title: "Tasks", systemImage: "checklist")
                tabButton(index: 2, title: "Files", systemImage: "folder")
                tabButton(index: 3, title: "Voice", systemImage: "waveform")
                tabButton(index: 4, title: "System", systemImage: "gearshape")
            }
            .frame(height: 64)
            .background(AppTheme.background)
            .border(AppTheme.primary, width: 1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == index
        let activeBg = AppTheme.secondary // Teal
        let activeFg = AppTheme.onSecondary
        
        return Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? activeBg : AppTheme.background)
            .foregroundStyle(isSelected ? activeFg : AppTheme.primary)
            .overlay(alignment: .trailing) {
                if index < 4 {
                    Rectangle()
                        .fill(AppTheme.primary)
                        .frame(width: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
