import CoreLocation

struct SightingCluster: Identifiable {
    let sightings: [CatSighting]

    var id: String { sightings.map { $0.id.uuidString }.sorted().joined() }
    var isCluster: Bool { sightings.count > 1 }

    var center: CLLocationCoordinate2D {
        let lat = sightings.map(\.latitude).reduce(0, +) / Double(sightings.count)
        let lon = sightings.map(\.longitude).reduce(0, +) / Double(sightings.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func compute(from sightings: [CatSighting], distance: CLLocationDistance) -> [SightingCluster] {
        guard !sightings.isEmpty else { return [] }
        let threshold = distance / 3_000_000.0
        var remaining = sightings
        var result: [SightingCluster] = []

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var group = [seed]
            var rest: [CatSighting] = []
            for s in remaining {
                if abs(s.latitude - seed.latitude) < threshold && abs(s.longitude - seed.longitude) < threshold {
                    group.append(s)
                } else {
                    rest.append(s)
                }
            }
            remaining = rest
            result.append(SightingCluster(sightings: group))
        }
        return result
    }
}
