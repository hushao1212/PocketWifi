import SwiftUI

struct TrafficView: View {
    @EnvironmentObject var store: TrafficStore
    @State private var showResetConfirm = false

    private var maxDayTotal: UInt64 {
        max(store.recentDays.map { $0.total }.max() ?? 1, 1)
    }

    private var monthWifi: UInt64 {
        let prefix = String(DayKey.today().prefix(7))
        return store.days.filter { $0.day.hasPrefix(prefix) }.reduce(0) { $0 + $1.wifiIn + $1.wifiOut }
    }

    private var monthCell: UInt64 {
        let prefix = String(DayKey.today().prefix(7))
        return store.days.filter { $0.day.hasPrefix(prefix) }.reduce(0) { $0 + $1.cellIn + $1.cellOut }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(alignment: .top, spacing: 20) {
                        summary("本月接收", ByteFormat.size(store.monthTotals.received), .blue)
                        summary("本月发送", ByteFormat.size(store.monthTotals.sent), .orange)
                    }
                    .padding(.vertical, 4)

                    HStack(alignment: .top, spacing: 20) {
                        summary("WiFi 流量", ByteFormat.size(monthWifi), .green)
                        summary("蜂窝流量", ByteFormat.size(monthCell), .purple)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("本月汇总")
                }

                Section {
                    if store.recentDays.isEmpty {
                        Text("还没有记录，联网后自动累计")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.recentDays) { day in
                            dayRow(day)
                        }
                    }
                } header: {
                    Text("每日明细")
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("清空全部流量记录")
                    }
                } footer: {
                    Text("只记录本机自身的收发字节，不读取运营商账单；数据存在本机，卸载即删。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("流量记录")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("确定清空所有记录？", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.reset() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func summary(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayRow(_ day: DailyUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.day).font(.subheadline.weight(.medium))
                Spacer()
                Text(ByteFormat.size(day.total))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 14) {
                Text("WiFi ↓\(ByteFormat.size(day.wifiIn)) ↑\(ByteFormat.size(day.wifiOut))")
                Text("蜂窝 ↓\(ByteFormat.size(day.cellIn)) ↑\(ByteFormat.size(day.cellOut))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            UsageBar(ratio: Double(day.total) / Double(maxDayTotal))
                .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

struct UsageBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: max(geo.size.width * CGFloat(min(max(ratio, 0), 1)), 2))
            }
        }
    }
}
