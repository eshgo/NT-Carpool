import Foundation
import CoreLocation

struct DriverDetourResult {
    let driver: User
    let detour: TimeInterval
}

class RideMatcher {
    private let firestoreService = FirestoreService()
    private let mapKitService = MapKitService()
    
    func findTopDrivers(passenger: User, passengerLocation: CLLocation, groupId: String, completion: @escaping ([DriverDetourResult]) -> Void) {
        firestoreService.fetchGroupMembers(groupId: groupId) { members in
            let drivers = members.filter { $0.isDriver && $0.defaultDestination != nil && $0.id != passenger.id }
            var detours: [DriverDetourResult] = []
            
            let group = DispatchGroup()
            
            for driver in drivers {
                group.enter()
                self.calculateDetourForDriver(
                    driver: driver,
                    passenger: passenger,
                    passengerLocation: passengerLocation
                ) { detour in
                    if let detour = detour {
                        detours.append(DriverDetourResult(driver: driver, detour: detour))
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                let sortedDetours = detours.sorted { $0.detour < $1.detour }
                completion(Array(sortedDetours.prefix(3)))
            }
        }
    }
    
    private func calculateDetourForDriver(
        driver: User,
        passenger: User,
        passengerLocation: CLLocation,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        guard let driverDestination = driver.defaultDestination else {
            completion(nil)
            return
        }
        
        guard let passengerDestination = passenger.defaultDestination else {
            completion(nil)
            return
        }
        
        // Get temporary location for the driver
        firestoreService.fetchTemporaryLocation(userId: driver.id!) { temporaryLocation in
            guard let temporaryLocation = temporaryLocation else {
                completion(nil)
                return
            }
            
            // Use temporary location
            self.calculateDetourWithLocation(
                driver: driver,
                driverLocation: temporaryLocation,
                passengerLocation: passengerLocation,
                driverDestination: driverDestination,
                passengerDestination: passengerDestination,
                completion: completion
            )
        }
    }
    
    private func calculateDetourWithLocation(
        driver: User,
        driverLocation: LastKnownLocation,
        passengerLocation: CLLocation,
        driverDestination: Location,
        passengerDestination: Location,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        let driverCoord = CLLocationCoordinate2D(latitude: driverLocation.latitude, longitude: driverLocation.longitude)
        let passengerCoord = passengerLocation.coordinate
        let driverDestinationCoord = CLLocationCoordinate2D(latitude: driverDestination.latitude, longitude: driverDestination.longitude)
        let passengerDestinationCoord = CLLocationCoordinate2D(latitude: passengerDestination.latitude, longitude: passengerDestination.longitude)
        
        let group = DispatchGroup()
        
        var baseETA: TimeInterval?
        var detourETA: TimeInterval?
        
        // Calculate base ETA: driver location to driver default destination
        group.enter()
        self.mapKitService.calculateETA(from: driverCoord, to: driverDestinationCoord) { eta in
            baseETA = eta
            group.leave()
        }
        
        // Calculate detour ETA: driver location → passenger location → passenger destination → driver destination
        group.enter()
        self.calculatePickupToDestinationDetour(
            driverCoord: driverCoord,
            passengerCoord: passengerCoord,
            passengerDestinationCoord: passengerDestinationCoord,
            driverDestinationCoord: driverDestinationCoord
        ) { eta in
            detourETA = eta
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let baseETA = baseETA, let detourETA = detourETA {
                completion(detourETA - baseETA)
            } else {
                completion(nil)
            }
        }
    }
    
    private func calculatePickupToDestinationDetour(
        driverCoord: CLLocationCoordinate2D,
        passengerCoord: CLLocationCoordinate2D,
        passengerDestinationCoord: CLLocationCoordinate2D,
        driverDestinationCoord: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        let group = DispatchGroup()
        
        var leg1ETA: TimeInterval? // Driver to passenger
        var leg2ETA: TimeInterval? // Passenger to passenger destination
        var leg3ETA: TimeInterval? // Passenger destination to driver destination
        
        // Leg 1: Driver location to passenger location
        group.enter()
        mapKitService.calculateETA(from: driverCoord, to: passengerCoord) { eta in
            leg1ETA = eta
            group.leave()
        }
        
        // Leg 2: Passenger location to passenger destination
        group.enter()
        mapKitService.calculateETA(from: passengerCoord, to: passengerDestinationCoord) { eta in
            leg2ETA = eta
            group.leave()
        }
        
        // Leg 3: Passenger destination to driver destination
        group.enter()
        mapKitService.calculateETA(from: passengerDestinationCoord, to: driverDestinationCoord) { eta in
            leg3ETA = eta
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let leg1ETA = leg1ETA, let leg2ETA = leg2ETA, let leg3ETA = leg3ETA {
                completion(leg1ETA + leg2ETA + leg3ETA)
            } else {
                completion(nil)
            }
        }
    }
}