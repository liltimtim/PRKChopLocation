//
//  File.swift
//  
//
//  Created by Timothy Dillman on 5/18/23.
//

import Foundation

public enum PRKChopLocationError: Error, LocalizedError {
    case permissionDeniedOrRestricted
    case locationNotDetermined
    case invalidAddress
    case invalidPermissionRequested
    
    public var errorDescription: String? {
        switch self {
        case .permissionDeniedOrRestricted: return "User denied permission or has restricted location availability."
        case .locationNotDetermined: return "Could not determine location or location service returned 0 results."
        case .invalidAddress: return "Could not convert geocoordinates to an address."
        case .invalidPermissionRequested: return "Requested invalid CLAuthorizationStatus when it should have been one of authorizedAlways or authorizedWhenInUse"
        
        }
    }
}
