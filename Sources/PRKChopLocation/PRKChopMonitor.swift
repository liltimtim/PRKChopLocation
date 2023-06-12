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

    internal var locationsContinuation: AsyncStream<CLLocation>.Continuation?
    
    public init(monitor: CLLocationManager = CLLocationManager(),
                locationUsageType: CLAuthorizationStatus = .authorizedWhenInUse) {
        super.init()
        self.monitor = monitor
        self.defaultLocationUsageType = locationUsageType
        self.monitor.delegate = self
    }
    
    public func beginMonitoringLocationChanges() -> AsyncStream<CLLocation> {
        #if os(iOS) || os(macOS)
        monitor.startUpdatingLocation()
        #endif
        return AsyncStream { cont in
            self.locationsContinuation?.finish()
            self.locationsContinuation = cont
            self.locationsContinuation?.onTermination = { _ in
                self.locationsContinuation = nil
                self.monitor.stopUpdatingLocation()
            }
        }
    }
    
    /// Requests permission to read the users current GPS location.
    ///
    /// Permission Type can be one of `.authorizedAlways` or `.authorizedWhenInUse` and any other permission type will result in an error of `PRKChopLocationError.invalidPermissionRequested`
    ///
    /// - Parameters:
    ///     - permissionType: one of `.authorizedWhenInUse` or `.authorizedAlways`
    @MainActor
    @discardableResult
    public func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus {
        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            switch permissionType {
            case .authorizedAlways:
                #if os(iOS) || os(macOS)
                monitor.requestAlwaysAuthorization()
                #else
                monitor.requestWhenInUseAuthorization()
                #endif
            case .authorizedWhenInUse:
                monitor.requestWhenInUseAuthorization()
            default:
                continuation.resume(with: .failure(PRKChopLocationError.invalidPermissionRequested))
                self.authorizationContinuation = nil
            }
        }
    }
    
    @MainActor
    public func getCurrentLocation() async throws -> CLLocation {
        switch authorizationStatus {
        #if os(iOS) || os(macOS)
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return try await currentLocation()
        #else
        case .authorizedWhenInUse:
            return try await currentLocation()
        #endif
        case .denied, .restricted:
            throw PRKChopLocationError.permissionDeniedOrRestricted
            
        case .notDetermined:
            try await requestPermission(with: .authorizedWhenInUse)
            return try await getCurrentLocation()
            
        case .authorizedAlways:
            return try await currentLocation()
            
        @unknown default:
            throw PRKChopLocationError.locationNotDetermined
        }
    }
    
    internal func currentLocation() async throws -> CLLocation {
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
            locationsContinuation?.finish()
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
