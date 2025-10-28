import SwiftUI
import CoreLocation
import Firebase

struct RideRequestView: View {
    @State var group: Group
    @State var currentUser: User
    @State private var topDrivers: [DriverDetourResult] = []
    @State private var showingResults = false
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var driverLocationManager = LocationManager()
    private let rideMatcher = RideMatcher()
    private let firestoreService = FirestoreService()
    
    var body: some View {
        VStack {
            if !showingResults {
                Button("Request Ride") {
                    // Request passenger location
                    locationManager.requestLocation()
                    // Request all drivers' locations
                    driverLocationManager.requestLocation()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                ResultView(drivers: topDrivers)
            }
        }
        .navigationTitle("Request a Ride")
        .onReceive(locationManager.$location) { location in
            if let location = location {
                // Find top drivers if user is a passenger
                if !currentUser.isDriver, let groupId = group.id, let passengerDestination = currentUser.defaultDestination {
                    self.findTopDrivers(passengerLocation: location, passengerDestination: passengerDestination)
                }
            }
        }
        .onReceive(driverLocationManager.$location) { location in
            if let location = location {
                // Create temporary locations for all drivers
                self.createTemporaryLocations(location: location)
            }
        }
        .background(Color.green.opacity(0.1))
    }
    
    private func createTemporaryLocations(location: CLLocation) {
        let timestamp = Timestamp()
        let temporaryLocation = LastKnownLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: timestamp
        )
        
        // Update current user's temporary location if they're a driver
        if currentUser.isDriver, let userId = currentUser.id {
            firestoreService.updateTemporaryLocation(userId: userId, location: temporaryLocation)
            // Schedule deletion after 5 minutes
            firestoreService.scheduleTemporaryLocationDeletion(userId: userId, timestamp: timestamp)
        }
        
        // Update other drivers' temporary locations in the same group
        firestoreService.fetchGroupMembers(groupId: group.id!) { members in
            let drivers = members.filter { $0.isDriver && $0.id != self.currentUser.id }
            for driver in drivers {
                if let userId = driver.id {
                    self.firestoreService.updateTemporaryLocation(userId: userId, location: temporaryLocation)
                    // Schedule deletion after 5 minutes
                    self.firestoreService.scheduleTemporaryLocationDeletion(userId: userId, timestamp: timestamp)
                }
            }
        }
    }
    
    private func findTopDrivers(passengerLocation: CLLocation, passengerDestination: Location) {
        rideMatcher.findTopDrivers(passenger: currentUser, passengerLocation: passengerLocation, groupId: group.id!) { drivers in
            DispatchQueue.main.async {
                self.topDrivers = drivers
                self.showingResults = true
            }
        }
    }
}