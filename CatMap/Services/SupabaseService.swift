import Foundation
import Supabase
import UIKit

@Observable
@MainActor
final class SupabaseService {
    var sightings: [CatSighting] = []
    var isUploading = false

    private let client = SupabaseClient(
        supabaseURL: URL(string: "https://YOUR_PROJECT_ID.supabase.co")!,
        supabaseKey: "YOUR_ANON_KEY"
    )
    private var realtimeTask: Task<Void, Never>?

    func startListening() {
        realtimeTask = Task {
            await loadSightings()
            await listenForChanges()
        }
    }

    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
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
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "sightings")
        await channel.subscribe()
        for await _ in changes {
            await loadSightings()
        }
    }

    func addSighting(latitude: Double, longitude: Double, image: UIImage?, note: String) async throws {
        isUploading = true
        defer { isUploading = false }

        var photoURL: String?
        var photoStoragePath: String?

        if let image, let data = image.jpegData(compressionQuality: 0.8) {
            let fileName = "\(UUID().uuidString).jpg"
            photoStoragePath = fileName

            try await client.storage
                .from("photos")
                .upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))

            photoURL = try client.storage
                .from("photos")
                .getPublicURL(path: fileName)
                .absoluteString
        }

        let insert = SightingInsert(
            latitude: latitude,
            longitude: longitude,
            photoUrl: photoURL,
            photoStoragePath: photoStoragePath,
            note: note
        )

        try await client
            .from("sightings")
            .insert(insert)
            .execute()
    }

    func deleteSighting(_ sighting: CatSighting) async throws {
        try await client
            .from("sightings")
            .delete()
            .eq("id", value: sighting.id.uuidString)
            .execute()

        if let path = sighting.photoStoragePath {
            try? await client.storage
                .from("photos")
                .remove(paths: [path])
        }
    }
}

private struct SightingInsert: Encodable {
    let latitude: Double
    let longitude: Double
    let photoUrl: String?
    let photoStoragePath: String?
    let note: String

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, note
        case photoUrl = "photo_url"
        case photoStoragePath = "photo_storage_path"
    }
}
