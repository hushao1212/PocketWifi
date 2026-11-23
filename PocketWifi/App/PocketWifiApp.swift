import SwiftUI

@main
struct PocketWifiApp: App {
    @StateObject private var store: TrafficStore
    @StateObject private var monitor: NetworkMonitor

    init() {
        let trafficStore = TrafficStore()
        _store = StateObject(wrappedValue: trafficStore)
        _monitor = StateObject(wrappedValue: NetworkMonitor(store: trafficStore))
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(monitor)
        }
    }
}
