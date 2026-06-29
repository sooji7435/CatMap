import Foundation
import Supabase
import UIKit

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
                .order("date", ascending: true)
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

    func addSighting(latitude: Double, longitude: Double, images: [UIImage], note: String) async throws {
        isUploading = true
        defer { isUploading = false }

        var photoURLs: [String] = []
        var photoStoragePaths: [String] = []

        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "\(UUID().uuidString).jpg"
            photoStoragePaths.append(fileName)

            try await client.storage
                .from("photos")
                .upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))

            let url = try client.storage
                .from("photos")
                .getPublicURL(path: fileName)
                .absoluteString
            photoURLs.append(url)
        }

        try await client
            .from("sightings")
            .insert(SightingInsert(
                latitude: latitude,
                longitude: longitude,
                photoURLs: photoURLs,
                photoStoragePaths: photoStoragePaths,
                note: note,
                userId: currentUserId
            ))
            .execute()
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
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, note
        case photoURLs = "photo_urls"
        case photoStoragePaths = "photo_storage_paths"
        case userId = "user_id"
    }
}
