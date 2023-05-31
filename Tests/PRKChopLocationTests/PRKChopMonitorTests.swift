//
//  PRKChopMonitorTests.swift
//  
//
//  Created by Timothy Dillman on 5/30/23.
//

import XCTest
@testable import PRKChopLocation
import CoreLocation

final class PRKChopMonitorTests: XCTestCase {
    var sut: PRKChopLocationMonitor!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Request Permission
    func test_requestPermission_denied() async {
        // given
        sut = .init(monitor: MockCLLocationManager(with: .denied), locationUsageType: .authorizedWhenInUse)
        // when
        do {
            let result = try await sut.requestPermission(with: .authorizedWhenInUse)
            XCTAssertEqual(result, .denied)
        } catch {
            XCTAssertEqual(error as! PRKChopLocationError, .permissionDeniedOrRestricted)
        }
    }
    
    func test_requestPermission_invalid_permission() async {
        // given
        sut = .init(monitor: MockCLLocationManager(with: .denied), locationUsageType: .authorizedWhenInUse)
        // when
        do {
            let result = try await sut.requestPermission(with: .denied)
            XCTAssertEqual(result, .denied)
        } catch {
            XCTAssertEqual(error as! PRKChopLocationError, .invalidPermissionRequested)
        }
    }
    
    // MARK: - get current location
    func test_getCurrentLocation_denied_permission_authorization_when_in_use() async {
        // given
        sut = .init(monitor: MockCLLocationManager(with: .denied), locationUsageType: .authorizedWhenInUse)
        
        // when
        do {
            _ = try await sut.getCurrentLocation()
            XCTFail("denied permission was expecting a failure")
        } catch {
            XCTAssertEqual(error as? PRKChopLocationError, PRKChopLocationError.permissionDeniedOrRestricted)
        }
    }
    
    func test_getCurrentLocation_denied_permission_authorization_always() async {
        // given
        sut = .init(monitor: MockCLLocationManager(with: .denied), locationUsageType: .authorizedAlways)
        
        // when
        do {
            _ = try await sut.getCurrentLocation()
            XCTFail("denied permission was expecting a failure")
        } catch {
            XCTAssertEqual(error as? PRKChopLocationError, PRKChopLocationError.permissionDeniedOrRestricted)
        }
    }
    
    func test_getCurrentLocation_permission_allowed_authorizedWhenInUse() async {
        // given
        let expectedLocation = CLLocation()
        sut = .init(monitor: MockCLLocationManager(with: .authorizedWhenInUse,
                                                  location: expectedLocation,
                                                  shouldSucceedGettingLocation: true),
                    locationUsageType: .authorizedWhenInUse)
        
        // when
        do {
            let result = try await sut.getCurrentLocation()
            XCTAssertEqual(result.coordinate.latitude, expectedLocation.coordinate.latitude)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test_getCurrentLocation_permission_allowed_authorizedAlways() async {
        // given
        let expectedLocation = CLLocation()
        sut = .init(monitor: MockCLLocationManager(with: .authorizedAlways,
                                                  location: expectedLocation,
                                                  shouldSucceedGettingLocation: true),
                    locationUsageType: .authorizedAlways)
        
        // when
        do {
            let result = try await sut.getCurrentLocation()
            XCTAssertEqual(result.coordinate.latitude, expectedLocation.coordinate.latitude)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - begin monitoring location changes
    
    func test_beginMonitoringLocationChanges_no_error() async {
        // given
        let expectedLocation = CLLocation()
        sut = .init(monitor: MockCLLocationManager(with: .authorizedWhenInUse,
                                                   location: expectedLocation,
                                                   shouldSucceedGettingLocation: true),
                    locationUsageType: .authorizedWhenInUse)
        // when
        _ = await sut.beginMonitoringLocationChanges().contains(expectedLocation)
    }
    
    /// In this test case, continously monitoring for locations does not throw any
    /// errors however it should call `.finish` on the async stream.
    func test_beginMonitoringLocationChanges_error() async {
        // given
        let expectedLocation = CLLocation()
        sut = .init(monitor: MockCLLocationManager(with: .authorizedWhenInUse,
                                                   location: expectedLocation,
                                                   shouldSucceedGettingLocation: false),
                    locationUsageType: .authorizedWhenInUse)
        // when
        var result: AsyncStream<CLLocation>?
        result = sut.beginMonitoringLocationChanges()
        for await item in result! {
            XCTAssertEqual(item.coordinate.latitude, expectedLocation.coordinate.latitude)
            result = nil
        }
    }
    
    func test_beginMonitoringLocationChanges_no_locations() async {
        // given
        let expectedLocation = CLLocation()
        sut = .init(monitor: MockCLLocationManager(with: .authorizedWhenInUse,
                                                   location: nil,
                                                   shouldSucceedGettingLocation: true),
                    locationUsageType: .authorizedWhenInUse)
        // when
        let result = await sut.beginMonitoringLocationChanges().contains(expectedLocation)
        XCTAssertFalse(result)
    }
}

class MockCLLocationManager: CLLocationManager {
    private var mockStatus: CLAuthorizationStatus!
    private var mockLocation: [CLLocation] = []
    private var succeedsGettingLocation: Bool!
    
    init(with status: CLAuthorizationStatus,
         location: CLLocation? = nil,
         shouldSucceedGettingLocation: Bool = true) {
        self.mockStatus = status
        if location != nil {
            self.mockLocation = [location!]
        } else {
            self.mockLocation = []
        }
        self.succeedsGettingLocation = shouldSucceedGettingLocation
        super.init()
    }
    
    override func startUpdatingLocation() {
        // we have to slightly delay this by switching to
        // main thread. This gives us time to setup the continuation
        // otherwise the delegate method is immediately called before the continuation is actually set.
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.succeedsGettingLocation ? self.delegate?.locationManager?(self, didUpdateLocations: self.mockLocation) : self.delegate?.locationManager?(self, didFailWithError: MockError.failedWithError)
        }
        
    }
    
    override var authorizationStatus: CLAuthorizationStatus {
        return mockStatus
    }
    
    override func requestAlwaysAuthorization() {
        delegate?.locationManagerDidChangeAuthorization?(self)
        succeedsGettingLocation ? delegate?.locationManager?(self, didUpdateLocations: mockLocation) : delegate?.locationManager?(self, didFailWithError: MockError.failedWithError)
    }
    
    override func requestWhenInUseAuthorization() {
        delegate?.locationManagerDidChangeAuthorization?(self)
        succeedsGettingLocation ? delegate?.locationManager?(self, didUpdateLocations: mockLocation) : delegate?.locationManager?(self, didFailWithError: MockError.failedWithError)
    }
    
    override func requestLocation() {
        succeedsGettingLocation ? delegate?.locationManager?(self, didUpdateLocations: mockLocation) : delegate?.locationManager?(self, didFailWithError: MockError.failedWithError)
    }
    
    enum MockError: Error {
        case failedWithError
    }
}
