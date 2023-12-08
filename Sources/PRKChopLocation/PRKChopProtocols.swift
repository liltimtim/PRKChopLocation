//
//  File.swift
//  
//
//  Created by Timothy Dillman on 5/30/23.
//

import Foundation
import CoreLocation
public protocol PRKChopCLGeocoderProtocol {
    func reverseGeocodeLocation(_ location: CLLocation) async throws -> any PRKChopCLPlacemarkProtocol
}

/// Replacement wrapper protocol for ``CoreLocation/CLPlacemark``.
public protocol PRKChopCLPlacemarkProtocol: Equatable {
    var address: String { get }
    var street: String { get }
    var city: String { get }
    var state: String { get }
    var postalCode: String { get }
}
