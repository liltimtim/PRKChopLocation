import Foundation
import CoreLocation

public final class PRKChopLocation {
    
    private var locationMonitor: PRKChopLocationMonitorProtocol!
    
    public init(monitor: PRKChopLocationMonitorProtocol = PRKChopLocationMonitor()) {
        self.locationMonitor = monitor
    }
    
    @MainActor
    public func getCurrentLocation() async throws -> CLLocation {
        return try await locationMonitor.getCurrentLocation()
    }
    
    public func address(from location: CLLocation) async throws -> CLPlacemark {
        let geo = CLGeocoder()
        guard let results = try await geo.reverseGeocodeLocation(location).first else { throw PRKChopLocationError.invalidAddress }
        return results
    }
    
    public func beginMonitoringLocation() -> AsyncStream<CLLocation> { locationMonitor.beginMonitoringLocationChanges() }
}
