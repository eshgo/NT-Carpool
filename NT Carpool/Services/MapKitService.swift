import Foundation
import MapKit

class MapKitService {
    func calculateETA(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, completion: @escaping (TimeInterval?) -> Void) {
        let sourcePlacemark = MKPlacemark(coordinate: from)
        let destinationPlacemark = MKPlacemark(coordinate: to)
        
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        let request = MKDirections.Request()
        request.source = sourceMapItem
        request.destination = destinationMapItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                completion(nil)
                return
            }
            completion(route.expectedTravelTime)
        }
    }
}