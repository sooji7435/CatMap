import Foundation
import CoreLocation

struct CatSighting: Identifiable, Codable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var photoURL: String?
    var photoStoragePath: String?
    var note: String
    var date: Date

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, note, date
        case photoURL = "photo_url"
        case photoStoragePath = "photo_storage_path"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
