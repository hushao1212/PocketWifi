import Foundation
import CoreTelephony
import SystemConfiguration.CaptiveNetwork
import Darwin

struct CellularSnapshot {
    var carrier: String = ""
    var radioTech: String = ""
    var signalRaw: Int?
    var bars: Int = 0
    var hasSIM: Bool = false
}

enum CarrierBridge {
    /// CTGetSignalStrength 是私有符号，TrollStore 环境下有机会直接调到。
    private static let signalFunction: (() -> Int32)? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_NOW),
              let symbol = dlsym(handle, "CTGetSignalStrength") else { return nil }
        typealias Fn = @convention(c) () -> Int32
        let fn = unsafeBitCast(symbol, to: Fn.self)
        return { fn() }
    }()

    static func snapshot() -> CellularSnapshot {
        var result = CellularSnapshot()
        let info = CTTelephonyNetworkInfo()

        if let providers = info.serviceSubscriberCellularProviders,
           let first = providers.values.first {
            result.carrier = first.carrierName ?? ""
            result.hasSIM = first.mobileCountryCode != nil || !result.carrier.isEmpty
        }

        if let tech = info.currentRadioAccessTechnology {
            result.radioTech = label(for: tech)
        }

        if let raw = signalFunction?() {
            result.signalRaw = Int(raw)
            result.bars = bars(for: Int(raw))
        }

        if result.radioTech.isEmpty && !result.hasSIM {
            result.radioTech = "无蜂窝"
        }
        return result
    }

    static func label(for tech: String) -> String {
        if tech == CTRadioAccessTechnologyLTE { return "4G LTE" }
        if tech == CTRadioAccessTechnologyNR || tech == CTRadioAccessTechnologyNRNSA { return "5G" }
        let threeG = [
            CTRadioAccessTechnologyWCDMA,
            CTRadioAccessTechnologyHSDPA,
            CTRadioAccessTechnologyHSUPA,
            CTRadioAccessTechnologyCDMA1x,
            CTRadioAccessTechnologyCDMAEVDORev0,
            CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB,
            CTRadioAccessTechnologyeHRPD
        ]
        if threeG.contains(tech) { return "3G" }
        if tech == CTRadioAccessTechnologyEdge || tech == CTRadioAccessTechnologyGPRS { return "2G" }
        return tech
    }

    /// CTGetSignalStrength 返回的是 0~100 的原始值，越大越好。
    static func bars(for raw: Int) -> Int {
        switch raw {
        case 80...: return 4
        case 60..<80: return 3
        case 40..<60: return 2
        case 20..<40: return 1
        default: return 0
        }
    }

    /// 当前 WiFi 名称。需要 wifi-info entitlement + 定位权限，否则返回 nil。
    static func currentSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for name in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String: AnyObject] else { continue }
            if let ssid = info[kCNNetworkInfoKeySSID as String] as? String, !ssid.isEmpty {
                return ssid
            }
        }
        return nil
    }
}
