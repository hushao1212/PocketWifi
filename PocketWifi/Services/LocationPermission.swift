import Foundation
import CoreLocation
import Combine

/// 只为了拿定位授权——iOS 读 SSID 必须有定位权限。
final class LocationPermission: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationPermission()

    @Published private(set) var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func requestIfNeeded() {
        status = manager.authorizationStatus
        guard status == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    var statusText: String {
        switch status {
        case .notDetermined: return "未请求"
        case .authorizedWhenInUse, .authorizedAlways: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        @unknown default: return "未知"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
