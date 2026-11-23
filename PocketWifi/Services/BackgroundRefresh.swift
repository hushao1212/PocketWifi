import Foundation
import BackgroundTasks

/// 没有真常驻权限时能做到的最接近「常驻」的机制：
/// 注册 BGAppRefresh，系统空闲时唤醒，采一次网卡计数并补记流量。
enum BackgroundRefresh {
    static let taskID = "com.example.PocketWifi.refresh"

    private static let baselineWifiIn = "bg.wifiIn"
    private static let baselineWifiOut = "bg.wifiOut"
    private static let baselineCellIn = "bg.cellIn"
    private static let baselineCellOut = "bg.cellOut"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            handle(task)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundRefresh] submit failed: \(error)")
        }
    }

    private static func handle(_ task: BGTask) {
        schedule()                       // 先排下一次，避免任务链断掉

        let work = DispatchWorkItem {
            sampleOnce()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }

        DispatchQueue.global(qos: .utility).async(execute: work)
    }

    /// 后台单次采样：用 UserDefaults 里的基线算增量，写进同一份流量账本。
    private static func sampleOnce() {
        let summary = NetworkSampler.summarize(NetworkSampler.readAll())
        let defaults = UserDefaults.standard

        let lastWifiIn = UInt64(defaults.integer(forKey: baselineWifiIn))
        let lastWifiOut = UInt64(defaults.integer(forKey: baselineWifiOut))
        let lastCellIn = UInt64(defaults.integer(forKey: baselineCellIn))
        let lastCellOut = UInt64(defaults.integer(forKey: baselineCellOut))

        let wifiIn = delta(summary.wifi.received, lastWifiIn)
        let wifiOut = delta(summary.wifi.sent, lastWifiOut)
        let cellIn = delta(summary.cell.received, lastCellIn)
        let cellOut = delta(summary.cell.sent, lastCellOut)

        if wifiIn + wifiOut + cellIn + cellOut > 0 {
            let store = TrafficStore()
            store.record(wifiIn: wifiIn, wifiOut: wifiOut, cellIn: cellIn, cellOut: cellOut)
            store.save()
        }

        defaults.set(Int(summary.wifi.received), forKey: baselineWifiIn)
        defaults.set(Int(summary.wifi.sent), forKey: baselineWifiOut)
        defaults.set(Int(summary.cell.received), forKey: baselineCellIn)
        defaults.set(Int(summary.cell.sent), forKey: baselineCellOut)
    }

    private static func delta(_ new: UInt64, _ old: UInt64) -> UInt64 {
        new >= old ? new - old : new
    }
}
