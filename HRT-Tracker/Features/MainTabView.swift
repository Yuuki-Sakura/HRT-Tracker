import SwiftUI
import HRTModels

struct MainTabView: View {
    @ObservedObject var vm: TimelineViewModel
    @State private var selectedTab: Tabs = .home

    enum Tabs: Hashable {
        case home, lab, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.home"), systemImage: "list.clipboard", value: Tabs.home) {
                HomeTab(vm: vm)
            }

            Tab(String(localized: "tab.lab"), systemImage: "flask", value: Tabs.lab) {
                LabTab(vm: vm)
            }

            Tab(String(localized: "tab.settings"), systemImage: "gearshape", value: Tabs.settings) {
                NavigationStack {
                    SettingsView(vm: vm)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainTabView(vm: .preview)
}
