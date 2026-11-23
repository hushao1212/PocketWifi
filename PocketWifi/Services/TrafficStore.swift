import Foundation
import Combine

/// 本地流量账本：按天累计，App 每次采样把增量记进来。
final class TrafficStore: ObservableObject {
    @Published private(set) var days: [DailyUsage] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("traffic-log.json")
    }

    private var lastSaved = Date.distantPast
    private let saveInterval: TimeInterval = 8

    init() {
        load()
    }

    var today: DailyUsage {
        days.first { $0.day == DayKey.today() } ?? DailyUsage(day: DayKey.today())
    }

    var monthTotals: (received: UInt64, sent: UInt64) {
        var inSum: UInt64 = 0
        var outSum: UInt64 = 0
        let prefix = String(DayKey.today().prefix(7))
        for day in days where day.day.hasPrefix(prefix) {
            inSum += day.totalIn
            outSum += day.totalOut
        }
        return (inSum, outSum)
    }

    var recentDays: [DailyUsage] {
        days.sorted { $0.day > $1.day }
    }

    /// 按「起始日 ~ 结束日」（yyyy-MM-dd 字符串可字典序比较）汇总一个计费周期。
    func totals(in cycle: UsageCycle) -> (received: UInt64, sent: UInt64, wifi: UInt64, cell: UInt64) {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var wifi: UInt64 = 0
        var cell: UInt64 = 0
        for day in days where day.day >= cycle.startKey && day.day <= cycle.endKey {
            received += day.totalIn
            sent += day.totalOut
            wifi += day.wifiIn + day.wifiOut
            cell += day.cellIn + day.cellOut
        }
        return (received, sent, wifi, cell)
    }

    func record(wifiIn: UInt64, wifiOut: UInt64, cellIn: UInt64, cellOut: UInt64) {
        let delta = wifiIn + wifiOut + cellIn + cellOut
        guard delta > 0 else { return }

        let key = DayKey.today()
        if let index = days.firstIndex(where: { $0.day == key }) {
            days[index].wifiIn += wifiIn
            days[index].wifiOut += wifiOut
            days[index].cellIn += cellIn
            days[index].cellOut += cellOut
        } else {
            var fresh = DailyUsage(day: key)
            fresh.wifiIn = wifiIn
            fresh.wifiOut = wifiOut
            fresh.cellIn = cellIn
            fresh.cellOut = cellOut
            days.append(fresh)
        }

        if Date().timeIntervalSince(lastSaved) > saveInterval {
            save()
        }
    }

    func reset() {
        days = []
        save()
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(days)
            try data.write(to: fileURL, options: .atomic)
            lastSaved = Date()
        } catch {
            print("[TrafficStore] save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            days = try JSONDecoder().decode([DailyUsage].self, from: data)
        } catch {
            print("[TrafficStore] load failed: \(error)")
        }
    }
}
