import CoreLocation
import os

/// 定位服务：请求一次 WhenInUse 权限，拿到当前坐标后反向地理编码得到国家码。
@MainActor
final class LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: "com.traveltranslator.app", category: "LocationService")

    private var continuation: CheckedContinuation<String?, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// 请求一次定位并返回 ISO 国家码（如 "JP"）。失败或被拒返回 nil。
    func currentCountryCode() async -> String? {
        if continuation != nil { return nil }

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        default:
            break
        }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    private func finish(_ code: String?) {
        continuation?.resume(returning: code)
        continuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            Task { @MainActor in self.finish(nil) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            Task { @MainActor in self.finish(nil) }
            return
        }
        Task { @MainActor in
            do {
                let placemarks = try await self.geocoder.reverseGeocodeLocation(loc)
                let code = placemarks.first?.isoCountryCode
                self.logger.info("定位国家码: \(code ?? "nil", privacy: .public)")
                self.finish(code)
            } catch {
                self.logger.error("反向地理编码失败: \(error.localizedDescription, privacy: .public)")
                self.finish(nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.logger.error("定位失败: \(error.localizedDescription, privacy: .public)")
            self.finish(nil)
        }
    }
}
