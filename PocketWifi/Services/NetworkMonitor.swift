import Foundation
import Combine

/// 每秒采样一次网卡计数，算出实时上下行速率，并把增量记进流量账本。
final class NetworkMonitor: ObservableObject {
    @Published private(set) var downSpeed: Double = 0
    @Published private(set) var upSpeed: Double = 0
    @Published private(set) var history: [RateSample] = []
    @Published private(set) var wifiTotals = InterfaceStats()
    @Published private(set) var cellTotals = InterfaceStats()
    @Published private(set) var isRunning = false

    private let store: TrafficStore
    private var timer: Timer?
    private var lastWifi: InterfaceStats?
    private var lastCell: InterfaceStats?
    private var lastTime: Date?
    private let maxSamples = 60

    init(store: TrafficStore) {
        self.store = store
    }

    func start() {
        guard timer == nil else { return }
        isRunning = true
        sample()                                   // 建立基线，第一拍不出数
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    deinit {
        timer?.invalidate()
    }

    private func sample() {
        let all = NetworkSampler.readAll()
        let summary = NetworkSampler.summarize(all)
        let now = Date()

        defer {
            lastWifi = summary.wifi
            lastCell = summary.cell
            lastTime = now
            wifiTotals = summary.wifi
            cellTotals = summary.cell
        }

        guard let prevWifi = lastWifi,
              let prevCell = lastCell,
              let prevTime = lastTime else { return }

        let dt = max(now.timeIntervalSince(prevTime), 0.2)

        let wifiIn = delta(new: summary.wifi.received, old: prevWifi.received)
        let wifiOut = delta(new: summary.wifi.sent, old: prevWifi.sent)
        let cellIn = delta(new: summary.cell.received, old: prevCell.received)
        let cellOut = delta(new: summary.cell.sent, old: prevCell.sent)

        downSpeed = Double(wifiIn + cellIn) / dt
        upSpeed = Double(wifiOut + cellOut) / dt

        history.append(RateSample(down: downSpeed, up: upSpeed))
        if history.count > maxSamples {
            history.removeFirst(history.count - maxSamples)
        }

        store.record(wifiIn: wifiIn, wifiOut: wifiOut, cellIn: cellIn, cellOut: cellOut)
    }

    /// 计数器回绕或重启时按新值重新起算，避免出现负数。
    private func delta(new: UInt64, old: UInt64) -> UInt64 {
        if new >= old { return new - old }
        return new
    }
}
