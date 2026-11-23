import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var store: TrafficStore

    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("sampleIntervalKey") private var sampleHint = true
    @AppStorage("cycleStartDay") private var cycleStartDay = 1
    @AppStorage("quotaGB") private var quotaGB = 0.0

    @ObservedObject private var location = LocationPermission.shared

    @State private var bgStatus = "未申请"
    @State private var toast: String?

    private var bridge = PrivateNetworkBridge.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    Stepper(value: $cycleStartDay, in: 1...28) {
                        HStack {
                            Text("每月起始日")
                            Spacer()
                            Text("\(cycleStartDay) 号").foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("月流量额度")
                        Spacer()
                        TextField("0 表示不设", value: $quotaGB, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        Text("GB").foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("当前周期")
                        Spacer()
                        Text(UsageCycle.current(startDay: cycleStartDay).display)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("套餐周期")
                } footer: {
                    Text("按运营商账单周期统计已用流量，首屏会显示「已用 / 额度 / 剩余」。额度只用于本地计算，不会联网。")
                }

                Section {
                    Toggle(isOn: $keepAwake) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("屏幕常亮")
                            Text("前台显示面板时不自动锁屏")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: keepAwake) { value in
                        UIApplication.shared.isIdleTimerDisabled = value
                    }

                    Button {
                        requestBackgroundRefresh()
                    } label: {
                        HStack {
                            Text("申请后台刷新")
                            Spacer()
                            Text(bgStatus).foregroundStyle(.secondary).font(.caption)
                        }
                    }

                    Button {
                        openURL("App-Prefs:root=BATTERY_USAGE")
                    } label: {
                        Text("后台刷新设置（系统）")
                    }
                } header: {
                    Text("常驻")
                } footer: {
                    Text("iOS 不允许第三方 App 真正常驻。这里用 BGAppRefresh 让系统定期唤醒采样，配合屏幕常亮做「挂在面板上」的效果。要做 24 小时不掉线的后台服务需要越狱装 daemon。")
                }

                Section {
                    row("私有网络接口", bridge.status)
                    row("WiFi 开关能力", wifiPowerText)
                    row("热点开关能力", bridge.isLoaded ? "已预留私有调用" : "仅能跳系统设置")
                    row("越狱环境", JailbreakCheck.isJailbroken ? "已检测到越狱" : "未检测到越狱")
                    HStack {
                        Text("定位权限")
                        Spacer()
                        Text(location.statusText).font(.caption).foregroundStyle(.secondary)
                        if location.status == .notDetermined {
                            Button("申请") { location.requestIfNeeded() }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                    row("WiFi 名称读取", CarrierBridge.currentSSID() != nil ? "正常" : "未读到（需定位授权 + wifi-info 权限）")
                } header: {
                    Text("能力诊断")
                } footer: {
                    Text("诊断结果取决于是否越狱 / 是否运行在 TrollStore 环境。未越狱时热点与 WiFi 开关一律走系统设置跳转。")
                }

                Section {
                    Button { openURL("App-Prefs:root=WIFI") } label: { Text("系统 WiFi 设置") }
                    Button { openURL("App-Prefs:root=INTERNET_TETHERING") } label: { Text("系统个人热点设置") }
                    Button { openURL("App-Prefs:root=MOBILE_DATA_SETTINGS_ID") } label: { Text("系统蜂窝数据设置") }
                    Button { openURL(UIApplication.openSettingsURLString) } label: { Text("本 App 权限设置") }
                } header: {
                    Text("快捷入口")
                }

                Section {
                    HStack {
                        Text("累计记录天数")
                        Spacer()
                        Text("\(store.days.count) 天").foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        store.reset()
                        show("记录已清空")
                    } label: {
                        Text("清空流量记录")
                    }
                } header: {
                    Text("数据")
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("设备")
                        Spacer()
                        Text("\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var wifiPowerText: String {
        guard let state = bridge.wifiPowerState else { return "不可用（未越狱）" }
        return "可用，当前\(state ? "开启" : "关闭")"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func requestBackgroundRefresh() {
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()
        bgStatus = "已提交任务"
        show("已提交后台刷新任务，系统决定何时执行")
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

enum JailbreakCheck {
    static var isJailbroken: Bool {
        let paths = [
            "/var/jb", "/Applications/Cydia.app", "/usr/sbin/sshd",
            "/bin/bash", "/private/var/lib/apt", "/var/lib/dpkg/status"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}
