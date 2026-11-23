import Foundation

/// 套餐计费周期：按「每月起始日」算，跨月自动回退。
struct UsageCycle {
    let startKey: String
    let endKey: String
    let startDay: Int

    var display: String {
        "\(startKey) ~ \(endKey)"
    }

    static func current(startDay: Int, now: Date = Date()) -> UsageCycle {
        let day = max(1, min(startDay, 28))
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone.current

        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let today = comps.day ?? 1

        var anchorComps = DateComponents()
        anchorComps.year = comps.year
        anchorComps.month = comps.month
        anchorComps.day = day
        let thisMonthAnchor = calendar.date(from: anchorComps) ?? now

        let start = today >= day
            ? thisMonthAnchor
            : (calendar.date(byAdding: .month, value: -1, to: thisMonthAnchor) ?? now)
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        let end = calendar.date(byAdding: .day, value: -1, to: nextStart) ?? now

        return UsageCycle(
            startKey: DayKey.formatter.string(from: start),
            endKey: DayKey.formatter.string(from: end),
            startDay: day
        )
    }
}
