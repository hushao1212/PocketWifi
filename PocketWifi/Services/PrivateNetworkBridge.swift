import Foundation

/// 通过 dlopen 调 MobileWiFi 私有框架，拿到 WiFi 开关、当前 SSID/RSSI、热点开关。
/// 没越狱 / 没 platform 权限时全部退化：读不到就返回 nil，界面自动改用公开接口 + 跳设置。
final class PrivateNetworkBridge {
    static let shared = PrivateNetworkBridge()

    private(set) var isLoaded = false
    private(set) var status = "未初始化"

    private var handle: UnsafeMutableRawPointer?
    private var client: UnsafeMutableRawPointer?

    private var getPower: (@convention(c) (UnsafeMutableRawPointer) -> Int32)?
    private var setPower: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Void)?
    private var copyDevices: (@convention(c) (UnsafeMutableRawPointer) -> CFArray?)?
    private var copyCurrentNetwork: (@convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?)?
    private var networkSSID: (@convention(c) (UnsafeMutableRawPointer) -> CFString?)?
    private var networkRSSI: (@convention(c) (UnsafeMutableRawPointer) -> Int32)?
    private var setHotspot: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Void)?

    private init() {
        load()
    }

    private func load() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW) else {
            status = "MobileWiFi 无法加载"
            return
        }
        handle = lib

        guard let createSym = dlsym(lib, "WiFiManagerClientCreate") else {
            status = "缺少 WiFiManagerClientCreate"
            return
        }
        typealias CreateFn = @convention(c) (CFAllocator?, Int32) -> UnsafeMutableRawPointer?
        let create = unsafeBitCast(createSym, to: CreateFn.self)
        client = create(kCFAllocatorDefault, 0)

        guard let wifiClient = client else {
            status = "WiFiManagerClient 创建失败（需要 platform 权限）"
            return
        }

        if let sym = dlsym(lib, "WiFiManagerClientGetPower") {
            getPower = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> Int32).self)
        }
        if let sym = dlsym(lib, "WiFiManagerClientSetPower") {
            setPower = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Void).self)
        }
        if let sym = dlsym(lib, "WiFiManagerClientCopyDevices") {
            copyDevices = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> CFArray?).self)
        }
        if let sym = dlsym(lib, "WiFiDeviceClientCopyCurrentNetwork") {
            copyCurrentNetwork = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?).self)
        }
        if let sym = dlsym(lib, "WiFiNetworkGetSSID") {
            networkSSID = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> CFString?).self)
        }
        if let sym = dlsym(lib, "WiFiNetworkGetRSSI") {
            networkRSSI = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> Int32).self)
        }
        if let sym = dlsym(lib, "WiFiManagerClientSetPersonalHotspotEnabled") {
            setHotspot = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Void).self)
        }

        _ = wifiClient

        if getPower == nil && setPower == nil {
            status = "私有符号不全，仅诊断可用"
            return
        }

        isLoaded = true
        var parts: [String] = []
        if setPower != nil { parts.append("WiFi开关可用") }
        if setHotspot != nil { parts.append("热点开关可用") } else { parts.append("热点符号缺失") }
        status = parts.joined(separator: "，")
    }

    var wifiPowerState: Bool? {
        guard let wifiClient = client, let fn = getPower else { return nil }
        return fn(wifiClient) != 0
    }

    func setWifiPower(_ on: Bool) -> Bool {
        guard let wifiClient = client, let fn = setPower else { return false }
        fn(wifiClient, on ? 1 : 0)
        return true
    }

    private func firstNetwork() -> UnsafeMutableRawPointer? {
        guard let wifiClient = client, let devicesFn = copyDevices, let copyNet = copyCurrentNetwork else { return nil }
        guard let devices = devicesFn(wifiClient) else { return nil }
        let count = CFArrayGetCount(devices)
        guard count > 0 else { return nil }
        for index in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(devices, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            if let network = copyNet(device) { return network }
        }
        return nil
    }

    func currentNetworkSSID() -> String? {
        guard let net = firstNetwork(), let fn = networkSSID else { return nil }
        guard let value = fn(net) else { return nil }
        let ssid = value as String
        return ssid.isEmpty ? nil : ssid
    }

    func currentNetworkRSSI() -> Int? {
        guard let net = firstNetwork(), let fn = networkRSSI else { return nil }
        return Int(fn(net))
    }

    /// 返回是否真的调用到了私有符号；false 表示只能跳系统设置。
    @discardableResult
    func setHotspotEnabled(_ on: Bool) -> Bool {
        guard let wifiClient = client, let fn = setHotspot else { return false }
        fn(wifiClient, on ? 1 : 0)
        return true
    }
}
