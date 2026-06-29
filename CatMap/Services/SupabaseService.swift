import Foundation
import Supabase
import UIKit
import CoreLocation

@Observable
@MainActor
final class SupabaseService {
    var sightings: [CatSighting] = []
    var isUploading = false
    private(set) var currentUserId: UUID?

    private let client = SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
    private var realtimeTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    func startListening() {
        realtimeTask = Task {
            await signInIfNeeded()
            await loadSightings()
            await listenForChanges()
        }
    }

    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
        let channel = realtimeChannel
        realtimeChannel = nil
        Task { await channel?.unsubscribe() }
    }

    func refresh() async {
        await loadSightings()
    }

    func isOwner(_ sighting: CatSighting) -> Bool {
        guard let currentUserId, let sightingUserId = sighting.userId else { return false }
        return currentUserId == sightingUserId
    }

    private func signInIfNeeded() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
        } catch {
            do {
                let session = try await client.auth.signInAnonymously()
                currentUserId = session.user.id
            } catch {
                print("Auth error: \(error)")
            }
        }
    }

    private func loadSightings() async {
        do {
            sightings = try await client
                .from("sightings")
                .select()
                .order("date", ascending: false)
                .execute()
                .value
        } catch {
            print("Load error: \(error)")
        }
    }

    private func listenForChanges() async {
        let channel = client.channel("sightings-realtime")
        realtimeChannel = channel
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "sightings")
        await channel.subscribe()
        for await _ in changes {
            await loadSightings()
        }
    }

    func addSighting(latitude: Double, longitude: Double, images: [UIImage], name: String?, note: String, status: String?) async throws {
        isUploading = true
        defer { isUploading = false }

        let (photoURLs, photoStoragePaths) = try await uploadImages(images)
        let locationName = await reverseGeocode(latitude: latitude, longitude: longitude)

        try await client
            .from("sightings")
            .insert(SightingInsert(
                latitude: latitude,
                longitude: longitude,
                photoURLs: photoURLs,
                photoStoragePaths: photoStoragePaths,
                note: note,
                name: name,
                userId: currentUserId,
                locationName: locationName,
                status: status
            ))
            .execute()
    }

    func addPhotos(to sighting: CatSighting, images: [UIImage]) async throws {
        isUploading = true
        defer { isUploading = false }

        let (newURLs, newPaths) = try await uploadImages(images)

        try await client
            .from("sightings")
            .update(PhotosUpdate(
                photoURLs: sighting.photoURLs + newURLs,
                photoStoragePaths: sighting.photoStoragePaths + newPaths
            ))
            .eq("id", value: sighting.id.uuidString)
            .execute()
    }

    private func uploadImages(_ images: [UIImage]) async throws -> (urls: [String], paths: [String]) {
        var urls: [String] = []
        var paths: [String] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "\(UUID().uuidString).jpg"
            paths.append(fileName)
            try await client.storage
                .from("photos")
                .upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))
            let url = try client.storage
                .from("photos")
                .getPublicURL(path: fileName)
                .absoluteString
            urls.append(url)
        }
        return (urls, paths)
    }

    private func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let p = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let parts = [p.locality, p.subLocality].compactMap { $0 }
                continuation.resume(returning: parts.isEmpty ? nil : parts.joined(separator: " "))
            }
        }
    }

    func deleteSighting(_ sighting: CatSighting) async throws {
        try await client
            .from("sightings")
            .delete()
            .eq("id", value: sighting.id.uuidString)
            .execute()

        if !sighting.photoStoragePaths.isEmpty {
            try? await client.storage
                .from("photos")
                .remove(paths: sighting.photoStoragePaths)
        }
    }

    func toggleLike(_ sighting: CatSighting) async throws {
        let key = "liked_\(sighting.id.uuidString)"
        let alreadyLiked = UserDefaults.standard.bool(forKey: key)
        let newLikes = max(0, sighting.likes + (alreadyLiked ? -1 : 1))

        try await client
            .from("sightings")
            .update(["likes": newLikes])
            .eq("id", value: sighting.id.uuidString)
            .execute()

        UserDefaults.standard.set(!alreadyLiked, forKey: key)
    }

    func isLiked(_ sighting: CatSighting) -> Bool {
        UserDefaults.standard.bool(forKey: "liked_\(sighting.id.uuidString)")
    }
}

private struct SightingInsert: Encodable {
    let latitude: Double
    let longitude: Double
    let photoURLs: [String]
    let photoStoragePaths: [String]
    let note: String
    let name: String?
    let userId: UUID?
    let locationName: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, note, name, status
        case photoURLs = "photo_urls"
        case photoStoragePaths = "photo_storage_paths"
        case userId = "user_id"
        case locationName = "location_name"
    }
}

private struct PhotosUpdate: Encodable {
    let photoURLs: [String]
    let photoStoragePaths: [String]

    enum CodingKeys: String, CodingKey {
        case photoURLs = "photo_urls"
        case photoStoragePaths = "photo_storage_paths"
    }
}
