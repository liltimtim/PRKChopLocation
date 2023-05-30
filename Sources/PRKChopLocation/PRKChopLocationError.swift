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
    
    public var errorDescription: String? {
        switch self {
        case .permissionDeniedOrRestricted: return "User denied permission or has restricted location availability."
        case .locationNotDetermined: return "Could not determine location or location service returned 0 results."
        case .invalidAddress: return "Could not convert geocoordinates to an address."
        }
    }
}
