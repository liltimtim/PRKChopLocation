import Foundation
import CoreLocation

public final class PRKChopLocation {
    
    private var locationMonitor: PRKChopLocationMonitorProtocol!
    
    private var geocoder: PRKChopCLGeocoderProtocol!
    
    public init(monitor: PRKChopLocationMonitorProtocol = PRKChopLocationMonitor(),
                geocoder: PRKChopCLGeocoderProtocol = PRKChopCLGeocoder()) {
        self.locationMonitor = monitor
        self.geocoder = geocoder
    }
    
    @MainActor
    public func getCurrentLocation() async throws -> CLLocation {
        return try await locationMonitor.getCurrentLocation()
    }
    
    @MainActor
    public func address(from location: CLLocation) async throws -> any PRKChopCLPlacemarkProtocol {
        return try await geocoder.reverseGeocodeLocation(location)
    }
    
    public func beginMonitoringLocation() -> AsyncStream<CLLocation> { locationMonitor.beginMonitoringLocationChanges() }
}
