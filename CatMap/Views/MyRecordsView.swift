import SwiftUI

struct MyRecordsView: View {
    @Environment(SupabaseService.self) private var supabase
    @State private var detailSighting: CatSighting?

    private var mySightings: [CatSighting] {
        supabase.sightings.filter { supabase.isOwner($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if mySightings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("내 기록")
            .sheet(item: $detailSighting) { CatDetailView(sighting: $0) }
        }
    }

    private var list: some View {
        List(mySightings) { sighting in
            Button { detailSighting = sighting } label: {
                row(for: sighting)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func row(for sighting: CatSighting) -> some View {
        HStack(spacing: 12) {
            thumbnail(for: sighting)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(for: sighting))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let location = sighting.locationName {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(sighting.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let s = sighting.catStatus {
                Image(systemName: s.systemImage)
                    .foregroundStyle(s.color)
            }
        }
        .padding(.vertical, 4)
    }

    private func thumbnail(for sighting: CatSighting) -> some View {
        Group {
            if let url = sighting.firstPhotoURL {
                CachedAsyncImage(url: url).scaledToFill()
            } else {
                Color.orange.opacity(0.2)
                    .overlay(Text("🐱").font(.title2))
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func displayTitle(for sighting: CatSighting) -> String {
        if let name = sighting.name, !name.isEmpty { return name }
        return sighting.note.isEmpty ? "이름 없는 고양이" : sighting.note
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.6))
            Text("아직 등록한 고양이가 없어요")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("지도에서 + 버튼을 눌러\n첫 번째 길냥이를 등록해보세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
