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
    var name: String?
    var userId: UUID?
    var locationName: String?
    var status: String?
    

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, note, date, likes, name, status
        case photoURLs = "photo_urls"
        case photoStoragePaths = "photo_storage_paths"
        case userId = "user_id"
        case locationName = "location_name"
    }

    var firstPhotoURL: URL? { photoURLs.first.flatMap { URL(string: $0) } }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var catStatus: CatStatus? { status.flatMap { CatStatus(rawValue: $0) } }
    var isNew: Bool { date > Date.now.addingTimeInterval(-7 * 24 * 3600) }
}

enum CatStatus: String, Codable, CaseIterable {
    case healthy = "healthy"
    case injured = "injured"
    case kitten  = "kitten"

    var label: String {
        switch self {
        case .healthy: return "건강해 보임"
        case .injured: return "다친 것 같음"
        case .kitten:  return "새끼 고양이"
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: return "heart.fill"
        case .injured: return "cross.case.fill"
        case .kitten:  return "star.fill"
        }
    }
}
