//
//  File.swift
//  
//
//  Created by Timothy Dillman on 5/30/23.
//

import Foundation
import CoreLocation
import Contacts

/// Struct wraps functionality for `CLGeocoder`
public struct PRKChopCLGeocoder: PRKChopCLGeocoderProtocol {
    private let decoder = CLGeocoder()
    
    public init() { }
    
    public func reverseGeocodeLocation(_ location: CLLocation) async throws -> any PRKChopCLPlacemarkProtocol {
        return try await withCheckedThrowingContinuation { continuation in
            decoder.reverseGeocodeLocation(location) { placemark, err in
                if err != nil {
                    continuation.resume(with: .failure(err!))
                    return
                }
                guard let placemark = placemark, let place = placemark.first else {
                    continuation.resume(with: .failure(PRKChopCLGeocoderErrors.noPlacemarker))
                    return
                }
                continuation.resume(with: .success(PRKChopCLPlacemark(with: place)))
            }
        }
    }
    
    public enum PRKChopCLGeocoderErrors: Error, LocalizedError {
        case noPlacemarker
    }
}

public struct PRKChopCLPlacemark: PRKChopCLPlacemarkProtocol {
    public var address: String
    
    public var street: String
    
    public var city: String
    
    public var state: String
    
    public var postalCode: String
    
    private var place: CLPlacemark?
    
    public init(with place: CLPlacemark) {
        self.place = place
        self.address = Self.formattedAddress(from: place)
        let postal = place.postalAddress
        self.street = postal?.street ?? ""
        self.city = postal?.city ?? ""
        self.state = postal?.state ?? ""
        self.postalCode = postal?.postalCode ?? ""
    }
    
    public init(street: String, city: String, state: String, postalCode: String) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.place = nil
        let postal = CNMutablePostalAddress()
        postal.street = street
        postal.city = city
        postal.state = state
        postal.postalCode = postalCode
        self.address = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
    }
    
    public static func formattedAddress(from placemark: CLPlacemark) -> String {
        return placemark.formattedAddress(style: .mailingAddress)
    }
}

extension PRKChopCLPlacemark {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.address == rhs.address
    }
}

public extension String {
    /// Removes all whitespace from `String` and calls `isEmpty` to see if the string was only comprised of empty spaces.
    var isEmptyWhitespace: Bool {
        var copy = self
        copy.removeAll { char in
            char == " "
        }
        return copy.isEmpty
    }
}

public extension CLPlacemark {
    func formattedAddress(style: CNPostalAddressFormatterStyle) -> String {
        guard let postalAddress = self.postalAddress else { return "" }
        return CNPostalAddressFormatter.string(from: postalAddress, style: style)
    }
}
