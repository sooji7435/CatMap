import SwiftUI

struct CatPreviewCard: View {
    let sighting: CatSighting
    let onDetail: () -> Void
    let onDismiss: () -> Void

    @Environment(SupabaseService.self) private var supabase
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var likeTask: Task<Void, Never>?

    private var live: CatSighting {
        supabase.sightings.first { $0.id == sighting.id } ?? sighting
    }

    private var displayTitle: String {
        if let name = live.name, !name.isEmpty { return name }
        return live.note.isEmpty ? "이름 없는 고양이" : live.note
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            info
            Spacer()
            actions
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .onAppear {
            isLiked = supabase.isLiked(live)
            likeCount = live.likes
        }
        .onChange(of: live.likes) { _, newValue in
            likeCount = newValue
        }
    }

    private var thumbnail: some View {
        Group {
            if let url = live.firstPhotoURL {
                CachedAsyncImage(url: url)
                    .scaledToFill()
            } else {
                catPlaceholder
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var catPlaceholder: some View {
        Color.orange.opacity(0.25)
            .overlay(Text("🐱").font(.largeTitle))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(displayTitle)
                .font(.subheadline.bold())
                .lineLimit(1)
            if let name = live.locationName {
                Label(name, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(live.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if live.photoURLs.count > 1 {
                Label("\(live.photoURLs.count)장", systemImage: "photo.on.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                likeToggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(.red)
                    Text("\(likeCount)")
                }
                .font(.caption)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: onDetail) {
                Text("자세히")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.orange)
                    .clipShape(Capsule())
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }

    private func likeToggle() {
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        likeTask?.cancel()
        likeTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? await supabase.setLike(live, liked: isLiked)
        }
    }
}
