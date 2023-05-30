//
//  File.swift
//  
//
//  Created by Timothy Dillman on 5/18/23.
//

import Foundation
import CoreLocation
public final class PRKChopLocationMonitor: NSObject, PRKChopLocationMonitorProtocol {
    private var monitor: CLLocationManager!
    private var defaultLocationUsageType: CLAuthorizationStatus!
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Error>?
    private var currentLocationContinuation: CheckedContinuation<CLLocation, Error>?
    public var authorizationStatus: CLAuthorizationStatus { return monitor.authorizationStatus }

    private var locationsContinuation: AsyncStream<CLLocation>.Continuation?
    
    public init(monitor: CLLocationManager = CLLocationManager(),
                locationUsageType: CLAuthorizationStatus = .authorizedWhenInUse) {
        super.init()
        self.monitor = monitor
        self.defaultLocationUsageType = locationUsageType
        self.monitor.delegate = self
    }
    
    public func beginMonitoringLocationChanges() -> AsyncStream<CLLocation> {
        monitor.startUpdatingLocation()
        return AsyncStream { cont in
            self.locationsContinuation?.finish()
            self.locationsContinuation = cont
            self.locationsContinuation?.onTermination = { _ in
                self.locationsContinuation = nil
                self.monitor.stopUpdatingLocation()
            }
        }
    }
    
    @MainActor
    @discardableResult
    public func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus {
        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            switch permissionType {
            case .authorizedAlways:
                monitor.requestAlwaysAuthorization()
            case .authorizedWhenInUse:
                monitor.requestWhenInUseAuthorization()
            default:
                fatalError("Requested invalid CLAuthorizationStatus when it should have been one of authorizedAlways or authorizedWhenInUse")
            }
        }
    }
    
    @MainActor
    public func getCurrentLocation() async throws -> CLLocation {
        switch authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return try await currentLocation()
            
        case .denied, .restricted:
            throw PRKChopLocationError.permissionDeniedOrRestricted
            
        case .notDetermined:
            try await requestPermission(with: .authorizedWhenInUse)
            return try await getCurrentLocation()
            
        @unknown default:
            throw PRKChopLocationError.locationNotDetermined
        }
    }
    
    private func currentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.currentLocationContinuation = continuation
            self.monitor.requestLocation()
        }
    }
}

extension PRKChopLocationMonitor: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(with: .success(manager.authorizationStatus))
        authorizationContinuation = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            currentLocationContinuation?.resume(throwing: PRKChopLocationError.locationNotDetermined)
            return
        }
        currentLocationContinuation?.resume(with: .success(location))
        currentLocationContinuation = nil
        locationsContinuation?.yield(location)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentLocationContinuation?.resume(throwing: error)
        currentLocationContinuation = nil
        locationsContinuation?.finish()
    }
}

public protocol PRKChopLocationMonitorProtocol {
    var authorizationStatus: CLAuthorizationStatus { get }
    @MainActor
    @discardableResult
    func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus
    @MainActor
    func getCurrentLocation() async throws -> CLLocation
    /// Starts monitoring for current location changes
    func beginMonitoringLocationChanges() -> AsyncStream<CLLocation>
}
