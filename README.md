# 随身 WiFi（PocketWifi）

iPhone X / iOS 16.0.2 + TrollStore 侧载的随身 WiFi 面板 App。

## 功能

- **实时速率**：每秒采样一次网卡计数，显示上下行速度 + 60 秒曲线
- **流量记录**：按天累计 WiFi / 蜂窝的收发字节，本月汇总、每日明细、可清空
- **运营商与信号**：运营商名称、网络制式（5G/4G/3G/2G）、信号格（`CTGetSignalStrength`）
- **WiFi 状态**：当前 SSID、RSSI（dBm）与强度分级
- **WiFi / 热点快捷操作**：优先尝试 MobileWiFi 私有接口，失败自动跳系统设置
- **常驻**：`BGAppRefresh` 后台定时采样 + 前台屏幕常亮 + 一跳直达系统后台设置
- **能力诊断**：显示私有接口是否就绪、是否检测到越狱环境

## 能力边界（iOS 限制，不是 bug）

| 想做 | 未越狱 | 越狱后 |
| --- | --- | --- |
| 实时速率 / 自记流量 | ✅ | ✅ |
| 读取 SSID | ✅ 需定位权限 | ✅ |
| 读取 RSSI、WiFi 开关 | ❌ | ✅ 私有接口 |
| 一键开热点 | ❌ 跳系统设置 | 需 daemon / 私有 hook |
| 真正常驻 | ❌ 仅后台刷新 | ✅ launchd daemon |

## 构建

无 Mac 方案：推送到 GitHub，Actions 用 `macos-latest` 出**无签名 IPA**，TrollStore 直接安装。

```bash
git push origin main        # 触发 .github/workflows/build-ipa.yml
```

产物在 Actions run 的 artifact `PocketWifi-ipa`。

## 工程约定

- 真源是 `project.yml`（XcodeGen），不要手改 `.xcodeproj`
- 部署目标 iOS 16.0；`SWIFT_VERSION 5.0` 规避 Swift 6 严格并发
- 不用 SwiftData / `#Preview` 宏 / `.topBarLeading`
- CI 里 `CODE_SIGNING_ALLOWED=NO`，签名交给 TrollStore

## 目录

```
PocketWifi/
├─ App/PocketWifiApp.swift
├─ Models/TrafficModels.swift
├─ Services/
│  ├─ NetworkSampler.swift        网卡计数（getifaddrs）
│  ├─ NetworkMonitor.swift        1s 采样 → 速率 + 曲线 + 记账
│  ├─ TrafficStore.swift          按天流量账本（JSON 落盘）
│  ├─ CarrierBridge.swift         运营商 / 制式 / 信号 / SSID
│  ├─ PrivateNetworkBridge.swift  MobileWiFi 私有接口（dlopen）
│  └─ BackgroundRefresh.swift     BGAppRefresh 后台采样
├─ Views/{Root,Dashboard,Traffic,Settings}View.swift
└─ Assets.xcassets
```
