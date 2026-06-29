import SwiftUI
import MapKit

struct CatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseService.self) private var supabase

    let sighting: CatSighting

    @State private var showDeleteAlert = false
    @State private var isLiked = false
    @State private var likeCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoGallery
                    infoSection
                    miniMapSection
                }
            }
            .navigationTitle("길냥이")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .alert("삭제할까요?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    Task {
                        try? await supabase.deleteSighting(sighting)
                        dismiss()
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 길냥이 기록이 삭제됩니다.")
            }
        }
        .onAppear {
            isLiked = supabase.isLiked(sighting)
            likeCount = sighting.likes
        }
    }

    @ViewBuilder
    private var photoGallery: some View {
        if !sighting.photoURLs.isEmpty {
            TabView {
                ForEach(sighting.photoURLs, id: \.self) { urlString in
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                            case .failure:
                                Color.gray.opacity(0.15)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    )
                            default:
                                Color.gray.opacity(0.1)
                                    .overlay(ProgressView())
                            }
                        }
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)
            .overlay(alignment: .bottomTrailing) {
                if sighting.photoURLs.count > 1 {
                    Text("\(sighting.photoURLs.count)장")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !sighting.note.isEmpty {
                Text(sighting.note)
                    .font(.body)
            }

            Button {
                likeToggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(.red)
                        .font(.title3)
                    Text(isLiked ? "좋아요 취소" : "좋아요")
                        .font(.subheadline)
                    Text("(\(likeCount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(sighting.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                Label(
                    String(format: "%.5f, %.5f", sighting.latitude, sighting.longitude),
                    systemImage: "location"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var miniMapSection: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: sighting.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))) {
            Annotation("", coordinate: sighting.coordinate) {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func likeToggle() {
        let newLiked = !isLiked
        isLiked = newLiked
        likeCount += newLiked ? 1 : -1
        Task {
            try? await supabase.toggleLike(sighting)
        }
    }
}
