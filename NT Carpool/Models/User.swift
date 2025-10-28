import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String?
    var name: String
    var isDriver: Bool
    var groups: [String]
    var defaultDestination: Location?
}

struct Group: Identifiable, Codable {
    var id: String?
    var name: String
    var inviteCode: String
    var members: [String]
}

struct Location: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var address: String
}

struct LastKnownLocation: Codable {
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp?
}