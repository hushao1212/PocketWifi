import Foundation

/// 一天的流量账目。day 形如 2026-11-23。
struct DailyUsage: Codable, Identifiable, Equatable {
    var id: String { day }
    var day: String
    var wifiIn: UInt64 = 0
    var wifiOut: UInt64 = 0
    var cellIn: UInt64 = 0
    var cellOut: UInt64 = 0

    var totalIn: UInt64 { wifiIn + cellIn }
    var totalOut: UInt64 { wifiOut + cellOut }
    var total: UInt64 { totalIn + totalOut }
}

/// 速率采样点，用于画曲线。
struct RateSample: Identifiable, Equatable {
    let id = UUID()
    let down: Double
    let up: Double
}

enum ByteFormat {
    static func speed(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        if value < 1024 { return String(format: "%.0f B/s", value) }
        if value < 1024 * 1024 { return String(format: "%.1f KB/s", value / 1024) }
        return String(format: "%.1f MB/s", value / 1024 / 1024)
    }

    static func size(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value < 1024 { return "\(bytes) B" }
        if value < 1024 * 1024 { return String(format: "%.1f KB", value / 1024) }
        if value < 1024 * 1024 * 1024 { return String(format: "%.1f MB", value / 1024 / 1024) }
        return String(format: "%.2f GB", value / 1024 / 1024 / 1024)
    }
}

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func today() -> String {
        formatter.string(from: Date())
    }
}
