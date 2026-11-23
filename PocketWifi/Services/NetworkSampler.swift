import Foundation
import Darwin

struct InterfaceStats: Equatable {
    var received: UInt64 = 0
    var sent: UInt64 = 0
}

/// 直接读网卡计数（getifaddrs），拿到的就是系统真实的收发字节。
enum NetworkSampler {
    static func readAll() -> [String: InterfaceStats] {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return [:] }
        defer { freeifaddrs(addrs) }

        var result: [String: InterfaceStats] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let entry = current.pointee
            cursor = entry.ifa_next

            guard let addr = entry.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let raw = entry.ifa_data else { continue }

            let name = String(cString: entry.ifa_name)
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            result[name] = InterfaceStats(
                received: UInt64(data.ifi_ibytes),
                sent: UInt64(data.ifi_obytes)
            )
        }
        return result
    }

    /// 汇总出 WiFi 与蜂窝两类接口的总计数。
    static func summarize(_ all: [String: InterfaceStats]) -> (wifi: InterfaceStats, cell: InterfaceStats) {
        var wifi = InterfaceStats()
        var cell = InterfaceStats()
        for (name, stats) in all {
            if name == "en0" {
                wifi.received += stats.received
                wifi.sent += stats.sent
            } else if name.hasPrefix("pdp_ip") {
                cell.received += stats.received
                cell.sent += stats.sent
            }
        }
        return (wifi, cell)
    }
}
