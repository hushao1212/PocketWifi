import SwiftUI
import UIKit
import Combine

struct DashboardView: View {
    @EnvironmentObject var store: TrafficStore
    @EnvironmentObject var monitor: NetworkMonitor

    @State private var cellular = CellularSnapshot()
    @State private var ssid: String?
    @State private var rssi: Int?
    @State private var privatePower: Bool?
    @State private var toast: String?
    @ObservedObject private var location = LocationPermission.shared
    @AppStorage("cycleStartDay") private var cycleStartDay = 1
    @AppStorage("quotaGB") private var quotaGB = 0.0

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    cycleCard
                    speedCard
                    signalCard
                    wifiCard
                    hotspotCard
                    todayCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("随身 WiFi")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                monitor.start()
                location.requestIfNeeded()
                refresh()
            }
            .onReceive(refreshTimer) { _ in refresh() }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - 卡片

    private var cycleCard: some View {
        let cycle = UsageCycle.current(startDay: cycleStartDay)
        let totals = store.totals(in: cycle)
        let used = totals.received + totals.sent
        let quotaBytes = UInt64(max(quotaGB, 0) * 1024 * 1024 * 1024)
        let ratio = quotaBytes > 0 ? Double(used) / Double(quotaBytes) : 0
        let remaining = quotaBytes > used ? quotaBytes - used : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("本周期用量", systemImage: "gauge")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(cycle.display)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ByteFormat.size(used))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if quotaBytes > 0 {
                    Text("/ \(ByteFormat.size(quotaBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if quotaBytes > 0 {
                    Text("\(Int(min(ratio, 1) * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ratio > 0.9 ? Color.red : Color.secondary)
                }
            }

            if quotaBytes > 0 {
                ProgressView(value: min(ratio, 1))
                    .tint(ratio > 0.9 ? .red : .accentColor)
                HStack {
                    Text("剩余 \(ByteFormat.size(remaining))")
                    Spacer()
                    Text("WiFi \(ByteFormat.size(totals.wifi)) · 蜂窝 \(ByteFormat.size(totals.cell))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                Text("还没设月额度：设置 → 套餐周期 → 月流量额度，填了就会显示剩余量")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("实时速率", systemImage: "speedometer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(monitor.isRunning ? "采样中" : "已停止")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                speedItem(title: "下载", value: ByteFormat.speed(monitor.downSpeed), symbol: "arrow.down.circle.fill", color: .blue)
                speedItem(title: "上传", value: ByteFormat.speed(monitor.upSpeed), symbol: "arrow.up.circle.fill", color: .green)
            }

            Sparkline(values: monitor.history.map { $0.down })
                .frame(height: 64)

            if let ssid {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                    Text(ssid)
                    if let rssi { Text("· \(rssi) dBm") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func speedItem(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("蜂窝网络", systemImage: "antenna.radiowaves.left.and.right")
                .font(.subheadline.weight(.semibold))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(cellular.carrier.isEmpty ? "未检测到运营商" : cellular.carrier)
                        .font(.headline)
                    Text(cellular.radioTech.isEmpty ? "—" : cellular.radioTech)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SignalBars(count: cellular.bars, total: 4)
            }

            if let raw = cellular.signalRaw {
                Text("原始信号值 \(raw) / 100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("信号强度需越狱后读取（当前显示操作系统公开信息）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var wifiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("WiFi 状态", systemImage: "wifi")
                .font(.subheadline.weight(.semibold))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ssid ?? ssidFallback)
                        .font(.headline)
                    Text(rssiText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let rssi {
                    SignalBars(count: wifiBars(rssi), total: 4)
                }
            }

            HStack(spacing: 10) {
                Button {
                    toggleWifi()
                } label: {
                    Label(wifiButtonTitle, systemImage: "power")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.bordered)

                Button {
                    openURL("App-Prefs:root=WIFI")
                } label: {
                    Label("WiFi 设置", systemImage: "gearshape")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    private var hotspotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("个人热点", systemImage: "personalhotspot")
                .font(.subheadline.weight(.semibold))

            Text("把手机变成随身 WiFi。iOS 限制第三方 App 直接开关热点，这里会先尝试私有接口，失败则跳转系统热点页。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    openHotspot()
                } label: {
                    Label("打开热点", systemImage: "bolt.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openURL("App-Prefs:root=INTERNET_TETHERING")
                } label: {
                    Label("热点设置", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.bordered)
            }

            Text(PrivateNetworkBridge.shared.status)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var todayCard: some View {
        let today = store.today
        return VStack(alignment: .leading, spacing: 12) {
            Label("今日用量", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                speedItem(title: "总接收", value: ByteFormat.size(today.totalIn), symbol: "arrow.down.to.line", color: .blue)
                speedItem(title: "总发送", value: ByteFormat.size(today.totalOut), symbol: "arrow.up.to.line", color: .orange)
            }

            Divider()

            HStack {
                usageRow("WiFi", in: today.wifiIn, out: today.wifiOut)
                usageRow("蜂窝", in: today.cellIn, out: today.cellOut)
            }
        }
        .cardStyle()
    }

    private func usageRow(_ title: String, in inbound: UInt64, out outbound: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("↓ \(ByteFormat.size(inbound))  ↑ \(ByteFormat.size(outbound))")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 逻辑

    private var ssidFallback: String {
        switch location.status {
        case .notDetermined: return "等待定位授权…"
        case .denied, .restricted: return "定位权限未开启，读不到 WiFi 名称"
        default: return "未连 WiFi，或缺少 wifi-info 权限"
        }
    }

    private var rssiText: String {
        guard let rssi else { return "信号强度不可读" }
        return "\(rssi) dBm · \(rssiLevel(rssi))"
    }

    private func rssiLevel(_ value: Int) -> String {
        if value >= -50 { return "很强" }
        if value >= -65 { return "良好" }
        if value >= -75 { return "一般" }
        return "偏弱"
    }

    private func wifiBars(_ value: Int?) -> Int {
        guard let value else { return 0 }
        if value >= -50 { return 4 }
        if value >= -65 { return 3 }
        if value >= -75 { return 2 }
        return 1
    }

    private var wifiButtonTitle: String {
        switch privatePower {
        case .some(true): return "关闭 WiFi"
        case .some(false): return "打开 WiFi"
        case .none: return "WiFi 开关"
        }
    }

    private func refresh() {
        cellular = CarrierBridge.snapshot()
        ssid = CarrierBridge.currentSSID() ?? PrivateNetworkBridge.shared.currentNetworkSSID()
        rssi = PrivateNetworkBridge.shared.currentNetworkRSSI()
        privatePower = PrivateNetworkBridge.shared.wifiPowerState
    }

    private func toggleWifi() {
        let target = !(privatePower ?? true)
        if PrivateNetworkBridge.shared.setWifiPower(target) {
            privatePower = target
            show("WiFi 已\(target ? "打开" : "关闭")")
        } else {
            show("无权限直接开关，请到系统设置")
            openURL("App-Prefs:root=WIFI")
        }
    }

    private func openHotspot() {
        if PrivateNetworkBridge.shared.setHotspotEnabled(true) {
            show("已通过私有接口请求开启热点")
        } else {
            show("跳转系统热点设置")
            openURL("App-Prefs:root=INTERNET_TETHERING")
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - 小组件

struct SignalBars: View {
    let count: Int
    let total: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < count ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: CGFloat(8 + index * 5))
            }
        }
        .frame(height: 24, alignment: .bottom)
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = .blue

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if values.count > 1 {
                    path(in: geo.size)
                        .stroke(color.opacity(0.85), lineWidth: 2)
                } else {
                    Text("采样中…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }

    private func path(in size: CGSize) -> Path {
        let peak = max(values.max() ?? 1, 1)
        var result = Path()
        guard values.count > 1 else { return result }
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat(value / peak))
            if index == 0 {
                result.move(to: CGPoint(x: x, y: y))
            } else {
                result.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return result
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
