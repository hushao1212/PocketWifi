import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: TrafficStore
    @EnvironmentObject var monitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("总览", systemImage: "wifi") }
            TrafficView()
                .tabItem { Label("流量", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                monitor.start()
            case .background:
                store.save()
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
