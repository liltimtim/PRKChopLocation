import XCTest
import CoreLocation
@testable import PRKChopLocation

final class PRKChopLocationTests: XCTestCase {
    var sut: PRKChopLocation!
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_requestPermission_denied() async {
        // given
        class MockMonitor: PRKChopLocationMonitorProtocol {
            func beginMonitoringLocationChanges() -> AsyncStream<CLLocation> {
                return AsyncStream { con in
                    con.yield(.init())
                }
            }
            
            var authorizationStatus: CLAuthorizationStatus { return .denied }
            
            func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus {
                return .denied
            }
            
            func getCurrentLocation() async throws -> CLLocation {
                throw PRKChopLocationError.permissionDeniedOrRestricted
            }
        }
        sut = PRKChopLocation(monitor: MockMonitor())
        // when
        do {
            _ = try await sut.getCurrentLocation()
        } catch {
            // then
            XCTAssertEqual(error.localizedDescription, PRKChopLocationError.permissionDeniedOrRestricted.localizedDescription)
        }
    }
    
    func test_requestPermission_allowed() async {
        // given
        class MockMonitor: PRKChopLocationMonitorProtocol {
            var authorizationStatus: CLAuthorizationStatus { return .denied }
            
            func requestPermission(with permissionType: CLAuthorizationStatus) async throws -> CLAuthorizationStatus {
                return .authorizedWhenInUse
            }
            
            func getCurrentLocation() async throws -> CLLocation {
                return .init()
            }
            
            func beginMonitoringLocationChanges() -> AsyncStream<CLLocation> {
                return AsyncStream { con in
                    con.yield(.init())
                }
            }
        }
        let givenLocation = CLLocation()
        sut = PRKChopLocation(monitor: MockMonitor())
        do {
            let result = try await sut.getCurrentLocation()
            XCTAssertEqual(result.coordinate.latitude, givenLocation.coordinate.latitude)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}

