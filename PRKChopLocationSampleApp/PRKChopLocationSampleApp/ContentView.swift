//
//  ContentView.swift
//  PRKChopLocationSampleApp
//
//  Created by Timothy Dillman on 5/17/23.
//

import SwiftUI
import PRKChopLocation
import CoreLocation

class ContentViewModel: ObservableObject {
    @Published var errorLabel: String?
    @Published var location: CLLocation?
    @Published private(set) var monitorButtonTitle: String = "Monitor Locations"
    private var monitor = PRKChopLocation()
    private var locationMonitorTask: Task<(), Error>?
    private var isMonitoringLocation: Bool = false
    func getCurrentLocation() {
        Task {
            do {
                
                location = try await monitor.getCurrentLocation()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func monitorLocation() {
        if isMonitoringLocation {
            stopMonitoringLocation()
        } else {
            isMonitoringLocation = true
            monitorButtonTitle = "Stop Monitoring Locations"
            locationMonitorTask?.cancel()
            locationMonitorTask = Task {
                _ = try await monitor.getCurrentLocation()
                for try await location in monitor.beginMonitoringLocation() {
                    print(location)
                }
            }
        }
    }
    
    func stopMonitoringLocation() {
        locationMonitorTask?.cancel()
        monitorButtonTitle = "Monitor Locations"
        isMonitoringLocation = false
    }
}

struct ContentView: View {
    
    @StateObject private var viewModel: ContentViewModel = .init()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            if viewModel.errorLabel != nil {
                Text(viewModel.errorLabel!)
            }
            if viewModel.location != nil {
                Text(viewModel.location?.description ?? "")
            }
            Button(action: viewModel.monitorLocation) {
                Text(viewModel.monitorButtonTitle)
            }
        }
        .padding()

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
