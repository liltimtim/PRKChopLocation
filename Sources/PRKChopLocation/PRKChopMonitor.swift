//
//  File.swift
//  
//
//  Created by Timothy Dillman on 5/18/23.
//

import Foundation
import CoreLocation

/// Core Location backed monitoring class
///
/// Allows grabbing the current user location once and requesting permission to do so or
/// grabbing a stream of location changes via `AsyncStream`.
public final class PRKChopLocationMonitor: NSObject, PRKChopLocationMonitorProtocol {
    private var monitor: CLLocationManager!
    private var defaultLocationUsageType: CLAuthorizationStatus!
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Error>?
    private var currentLocationContinuation: CheckedContinuation<CLLocation, Error>?
    public var authorizationStatus: CLAuthorizationStatus { return monitor.authorizationStatus }

    internal var locationsContinuation: AsyncStream<CLLocation>.Continuation?
    
    /// Initializer for ``PRKChopLocationMonitor`` with default implementations if none given
    ///
    /// By default, the location permission type wiill be authorized always.
    ///
    /// - Parameters:
    ///     - monitor: the location manager `CLLocationManager`
    ///     - locationUsageType: the permission type to use can be one of authorized when in use or always.
    public init(monitor: CLLocationManager = CLLocationManager(),
                locationUsageType: CLAuthorizationStatus = {
        return .authorizedAlways
    }()) {
        super.init()
        self.monitor = monitor
        self.defaultLocationUsageType = locationUsageType
        self.monitor.delegate = self
    }
    
    /// Starts real time location changes monitoring
    ///
    /// If the OS is one of iOS or macOS, it will invoke the start updating
    /// location function which will begin monitoring for location changes.
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
    
    /**
     Retrieves the current location asynchronously.

     - Returns: A `CLLocation` object representing the current location.

     - Throws:
       - `PRKChopLocationError.permissionDeniedOrRestricted`: When location permission is denied or restricted.
       - `PRKChopLocationError.locationNotDetermined`: When the location authorization status is unknown.

     - Note: This function is marked with `@MainActor` to ensure it is executed on the main actor.

     - Requires: The application must have the necessary permissions to access location services.

     Example usage:

     ```swift
     do {
         let currentLocation = try await getCurrentLocation()
         // Use the current location as needed
     } catch {
         // Handle errors
     }
     */
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
            #if os(macOS)
            try await requestPermission(with: .authorizedAlways)
            #else
            try await requestPermission(with: .authorizedWhenInUse)
            #endif
            return try await getCurrentLocation()
            
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

/// Defines the behavior of class or struct that will be a wrapper around some CoreLocation frameworks.
public protocol PRKChopLocationMonitorProtocol {
    var authorizationStatus: CLAuthorizationStatus { get }
    /// Request permission and return an authorization status based on user choice.
    ///
    /// This is an async method.
    ///
    /// - Parameters:
    ///     - permissionType: use permission type to request either authorized when in use or always permission. Giving a permission other than those two will result in an error.
    @MainActor
    @discardableResult
    func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus
    /// One off method that grabs the user's current location
    @MainActor
    func getCurrentLocation() async throws -> CLLocation
    /// Starts monitoring for current location changes
    func beginMonitoringLocationChanges() -> AsyncStream<CLLocation>
}
