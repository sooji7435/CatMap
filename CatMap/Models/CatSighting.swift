import Foundation
import CoreLocation

struct CatSighting: Identifiable, Codable, Equatable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var photoURLs: [String]
    var photoStoragePaths: [String]
    var note: String
    var date: Date
    var likes: Int

    var userId: UUID?
    var locationName: String?

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, note, date, likes
        case photoURLs = "photo_urls"
        case photoStoragePaths = "photo_storage_paths"
        case userId = "user_id"
        case locationName = "location_name"
    }

    var firstPhotoURL: URL? {
        photoURLs.first.flatMap { URL(string: $0) }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
